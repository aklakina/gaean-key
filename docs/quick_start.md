# Quick Start

## Prerequisites

- [Terramate](https://terramate.io/) 0.17+
- [OpenTofu](https://opentofu.org/) 1.12+
- Python 3.10+ with [PyYAML](https://pypi.org/project/PyYAML/) (`pip install pyyaml`) for the stack sync script
- Credentials for the services you use (see step 2)

## Basic Usage

All commands run from the repository root.

### 1. Pick the configurations

Copy the example configurations you need from [`examples/configurations/`](../examples/configurations) into `configurations/` and adapt them, or write your own (reference: [Available Extensions](./available_extensions.md)). Remove the `test_service` sample configurations once you don't need them anymore (destroy their stacks first, see [Removing a configuration](#removing-a-configuration)).

```bash
cp -r examples/configurations/gitlab examples/configurations/github configurations/
```

### 2. Provide provider credentials

Each stack configures only the provider of its own extension. Give the services you use their credentials through the providers' standard environment variables, for example:

```bash
export GITLAB_TOKEN=...         # gitlab rotation
export GITHUB_TOKEN=...         # github deployment
export GITHUB_OWNER=my-org
```

In CI, prefer federation for the clouds themselves (e.g. `ARM_USE_OIDC=true` for Azure, an assumed role for AWS) so the rotation pipeline holds no long-lived secret of its own.

Optional non-secret settings (AWS region/profile, GitHub owner/URL, GitLab URL, tenant, subscription) can also be set as Terramate globals, e.g. in `stacks/providers.tm.hcl`:

```hcl
globals "provider_settings" "github" {
  owner = "my-org"
}
globals "provider_settings" "gitlab" {
  base_url = "https://gitlab.example.com/api/v4"
}
```

### 3. Protect the state

Rotated credentials are stored in the OpenTofu state and plan of their stacks. Generate a remote backend only the rotation pipeline can read, and [state and plan encryption](https://opentofu.org/docs/language/state/encryption/), into the stacks (see [Stacks](./stacks.md#state-backend)). Without one, every stack keeps a local, unencrypted `terraform.tfstate`.

### 4. Turn the configurations into stacks

```bash
python scripts/sync_stacks.py   # writes stacks/<service>/<stage>/<id>/stack.tm.hcl
terramate generate              # generates the OpenTofu code inside every stack
```

Rerun both whenever you add, remove or move a configuration file, or change which credentials a
configuration references (editing other values needs no sync: the YAML is read by OpenTofu at plan time).
Commit the stacks and the generated files: Terramate refuses to run with uncommitted changes unless you
pass `--disable-safeguards=git` (`-X`).

### 5. Run OpenTofu in the stacks

Credentials flow between stacks through Terramate outputs sharing, so always pass `--enable-sharing`:

```bash
terramate run --enable-sharing --mock-on-fail -- tofu init
terramate run --enable-sharing --mock-on-fail -- tofu plan    # preview (see the note below)
terramate run --enable-sharing -- tofu apply
```

Terramate runs the stacks in dependency order (producers before their consumers); `-j <n>` runs
independent stacks in parallel.

> [!NOTE]
> A consumer's plan uses the producer's **current** (applied) output, or a mock value if the producer was
> never applied (`--mock-on-fail`; applying with a mock is refused). A credential that is about to rotate therefore only reaches its
> consumers' plans after the producer stack was applied. `terramate run ... -- tofu apply` handles that by
> applying the stacks in order.

### Scheduled rotation

Rotation is driven by time, not by commits, so a scheduled job should apply every rotation stack together
with everything that consumes them:

```bash
terramate run --enable-sharing --tags rotation --include-all-dependents -- tofu apply -auto-approve
```

### Only what changed

```bash
terramate run --changed --include-all-dependents --enable-sharing -- tofu apply
```

A stack counts as changed when its configuration files, `service.yml`, its stack or generated files, or a
local module it uses (engine modules, extension code) changed compared to the default branch.

### One credential and its consumers

```bash
terramate run --chdir stacks/<service>/rotation/<id> --include-all-dependents --enable-sharing -- tofu apply
```

### Removing a configuration

Destroy its stack **before** removing the configuration, then remove the stack:

```bash
terramate run --chdir stacks/<service>/<stage>/<id> --enable-sharing --mock-on-fail -- tofu destroy
# delete the configuration file, or disable it by renaming it (e.g. to <name>.yml.old)
python scripts/sync_stacks.py --prune
terramate generate
```

`sync_stacks.py` never deletes a stack on its own: without `--prune` it only reports orphaned stacks, and
`--prune` refuses to delete a stack whose local state still has resources.
