"""Unit tests of scripts/sync_stacks.py. Run from the repo root: python -m unittest discover -s tests"""

import io
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import sync_stacks  # noqa: E402

GET_EXT = """
variable "configurations" {}
output "secret" { value = {} }
"""
ROTATION_EXT = """
variable "configs" {}
variable "secrets" {}
output "secrets" { value = {} }
"""
DEPLOYMENT_EXT = """
variable "configurations" {}
variable "secrets" {}
"""


class SyncStacksTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.write("extensions/svc/get/main.tf", GET_EXT)
        self.write("extensions/svc/rotation/main.tf", ROTATION_EXT)
        self.write("extensions/svc/deployment/main.tf", DEPLOYMENT_EXT)
        self.write("configurations/svc/get/static.yml", "username: u\nsecret: s\n")
        self.write("configurations/svc/rotation/nested/dyn.yml", "expires_in: 2m\nparent:\n  service: svc\n  id: static\n")
        self.write(
            "configurations/svc/deployment/consumer/a/one.yml",
            "id: a\nsecret:\n  service: svc\n  id: static\n",
        )
        self.write(
            "configurations/svc/deployment/consumer/b/two.yml",
            "id: b\nsecret:\n  service: svc\n  id: nested/dyn\n",
        )
        self.write("configurations/svc/deployment/consumer/c/three.yml.old", "id: c\nsecret:\n  service: svc\n  id: gone\n")

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel, content):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def sync(self, **kwargs):
        out = io.StringIO()
        rc = sync_stacks.sync(self.root, out=out, **kwargs)
        return rc, out.getvalue()

    def stack(self, rel):
        return (self.root / rel / "stack.tm.hcl").read_text(encoding="utf-8")

    def test_one_stack_per_credential_and_deployment_unit(self):
        rc, _ = self.sync()
        self.assertEqual(rc, 0)
        stacks = sorted(p.parent.relative_to(self.root).as_posix() for p in self.root.glob("stacks/**/stack.tm.hcl"))
        self.assertEqual(
            stacks,
            ["stacks/svc/deployment/consumer", "stacks/svc/get/static", "stacks/svc/rotation/nested/dyn"],
        )

    def test_deployment_imports_only_referenced_credentials(self):
        self.sync()
        content = self.stack("stacks/svc/deployment/consumer")
        static_input = sync_stacks.input_name("svc", "static")
        dyn_input = sync_stacks.input_name("svc", "nested/dyn")
        self.assertIn(f'input "{static_input}"', content)
        self.assertIn(f'input "{dyn_input}"', content)
        self.assertIn(f'from_stack_id = "{sync_stacks.stack_id("get", "svc", "static")}"', content)
        self.assertIn('"/stacks/svc/get/static"', content)  # after
        self.assertIn('"/stacks/svc/rotation/nested/dyn"', content)
        self.assertNotIn("three.yml", content)  # disabled config
        self.assertNotIn('output "credential"', content)

    def test_producer_exports_credential_and_rotation_gets_its_refs(self):
        self.sync()
        rotation = self.stack("stacks/svc/rotation/nested/dyn")
        self.assertIn('output "credential"', rotation)
        self.assertIn('config_var    = "configs"', rotation)
        self.assertIn('output_name   = "secrets"', rotation)
        self.assertIn("pass_secrets  = true", rotation)
        self.assertIn(f'input "{sync_stacks.input_name("svc", "static")}"', rotation)
        # the get extension takes no secrets, so a get config is never wired to other stacks
        self.assertNotIn("input ", self.stack("stacks/svc/get/static"))

    def test_placeholders_need_no_producer(self):
        self.write("configurations/svc/deployment/other/x.yml", "secret:\n  service: TBD\n  id: TBD\n")
        rc, _ = self.sync()
        self.assertEqual(rc, 0)
        self.assertNotIn("input ", self.stack("stacks/svc/deployment/other"))

    def test_duplicate_credential_is_a_conflict(self):
        self.write("configurations/svc/rotation/static.yml", "expires_in: 2m\n")
        with self.assertRaisesRegex(sync_stacks.SyncError, "Conflict: credential svc/static"):
            self.sync()

    def test_missing_producer_is_an_error(self):
        self.write("configurations/svc/deployment/other/x.yml", "secret:\n  service: svc\n  id: nope\n")
        with self.assertRaisesRegex(sync_stacks.SyncError, "no get or rotation config produces svc/nope"):
            self.sync()

    def test_missing_extension_component_is_an_error(self):
        self.write("configurations/other/get/x.yml", "a: b\n")
        with self.assertRaisesRegex(sync_stacks.SyncError, "extensions/other/get/ does not"):
            self.sync()

    def test_store_component_serves_deployment_configs(self):
        self.write("extensions/vault/store/main.tf", DEPLOYMENT_EXT)
        self.write("extensions/vault/store/gaean.tm.hcl", "")
        self.write("configurations/vault/deployment/secret/x.yml", "secret:\n  service: svc\n  id: static\n")
        self.sync()
        content = self.stack("stacks/vault/deployment/secret")
        self.assertIn('extension     = "extensions/vault/store"', content)
        self.assertIn('source = "/extensions/vault/store/gaean.tm.hcl"', content)  # provider hook

    def test_service_yml_is_watched_and_its_refs_apply(self):
        self.write("configurations/svc/service.yml", "fallback:\n  service: svc\n  id: static\n")
        self.sync()
        get_stack = self.stack("stacks/svc/get/static")
        self.assertIn('"/configurations/svc/service.yml"', get_stack)
        self.assertIn('"configurations/svc/service.yml"', get_stack)

    def test_check_mode(self):
        rc, _ = self.sync(check=True)
        self.assertEqual(rc, 1)
        self.assertFalse((self.root / "stacks").exists())
        self.sync()
        rc, out = self.sync(check=True)
        self.assertEqual(rc, 0, out)

    def test_orphans_are_reported_and_pruned_only_without_state(self):
        self.sync()
        (self.root / "configurations/svc/get/static.yml").unlink()
        self.write("configurations/svc/deployment/consumer/a/one.yml", "id: a\nsecret:\n  service: none\n  id: none\n")
        self.write("configurations/svc/rotation/nested/dyn.yml", "expires_in: 2m\n")
        rc, out = self.sync(check=True)
        self.assertEqual(rc, 1)
        self.assertIn("orphan: stacks/svc/get/static", out)

        orphan = self.root / "stacks/svc/get/static"
        (orphan / "terraform.tfstate").write_text(json.dumps({"resources": [{"type": "x"}]}), encoding="utf-8")
        with self.assertRaisesRegex(sync_stacks.SyncError, "destroy them first"):
            self.sync(do_prune=True)

        (orphan / "terraform.tfstate").write_text(json.dumps({"resources": []}), encoding="utf-8")
        (orphan / "_gaean_get.tf").write_text("// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT\n", encoding="utf-8")
        rc, out = self.sync(do_prune=True)
        self.assertEqual(rc, 0)
        self.assertFalse((self.root / "stacks/svc/get").exists())

    def test_ids_are_valid_terramate_identifiers(self):
        long_id = "a/" * 40 + "x.y"
        sid = sync_stacks.stack_id("rotation", "svc", long_id)
        self.assertRegex(sid, r"^[A-Za-z0-9_-]{1,64}$")
        self.assertNotEqual(sid, sync_stacks.stack_id("rotation", "svc", long_id + "z"))
        self.assertRegex(sync_stacks.input_name("svc", long_id), r"^[A-Za-z][A-Za-z0-9_]*$")
        self.assertRegex(sync_stacks.tag("TBD.Service"), r"^[a-z0-9_-]+$")

    def test_template_sequences_are_escaped(self):
        self.assertEqual(sync_stacks.hcl("a${b}%{c}"), '"a$${b}%%{c}"')


if __name__ == "__main__":
    unittest.main()
