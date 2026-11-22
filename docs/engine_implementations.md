# Engine implementations

Gaean Key has two implementations of the engine. They share the configuration format, the extensions and the rotation semantics; they differ in how the OpenTofu code is organized and run.

| Branch | Engine | Tooling |
|---|---|---|
| [`master`](https://github.com/aklakina/gaean-key/tree/master) | One OpenTofu root module: `modules/load_configs`, `get`, `rotate`, `deploy` wire every configuration into one plan and one state | OpenTofu >= 1.13 |
| [`implementation/terramate`](https://github.com/aklakina/gaean-key/tree/implementation/terramate) | One [Terramate](https://terramate.io/) stack per credential and per deployment unit, generated from `configurations/`, wired by the credentials they reference | OpenTofu >= 1.12, Terramate 0.17, Python 3 with PyYAML |

`master` is the default and the more conservative choice. `implementation/terramate` is an alternative that scales better but depends on an experimental Terramate feature (outputs sharing).

## What both have in common

- **Configuration format**: `configurations/<service>/{get,rotation,deployment}/**.yml`, `service.yml` defaults, `config_file` on deployment configs, `*.yml.old` to disable a config.
- **Credential references**: consumers reference `secret: {service, id}`; placeholders `none/none` and `TBD/TBD`; a `service/id` can be retrieved or rotated, not both.
- **Rotation**: the dual-phase scheme with `expires_in` and `rotation_window` (default 20%), the same phase arithmetic, and the `create_before_destroy` timers from the [2026-03-03 ADR](./adr/20260303-fix-circular-dependency-in-rotation-lifecycle.md).
- **Extensions**: identical extension code (`aws`, `azuread`, `gitlab`, `github`, `azure_keyvault`, `test_service`) and the same extension contract, so an extension written for one runs on the other. Only the provider wiring around them differs.
- **Examples**: the same `examples/configurations/`.

## Comparison

| | `master` (root module) | `implementation/terramate` (stacks) |
|---|---|---|
| Tools to learn and install | OpenTofu | OpenTofu, Terramate, Python |
| Failure isolation | one plan for everything: a broken or unreachable service blocks the whole run | each credential / deployment unit has its own stack and state: failures stay in their stacks |
| Plan preview of a rotation | one plan shows every credential and consumer a rotation touches | a consumer's plan shows the producer's current credential; the full effect is visible only after the producer is applied |
| Adding a rotated service | edit the engine: `phase1`/`phase2` modules, outputs, gated provider, versions | no engine change: stacks and code are generated |
| Credentials a consumer receives | the full credential map | only the credentials its configs reference |
| Providers | declared in the engine modules, gated on `configurations/<service>/` so unused providers are never configured | each stack configures only its own extension's provider (`gaean.tm.hcl`) |
| Selective runs | `-target` only (pulls in rotation, use with care) | `--changed`, `--tags`, `--include-all-dependents`, parallel `-j` |
| State | one state | one state per stack: backend and state encryption are generated into every stack |
| Secrets in transit | stay inside one OpenTofu process | passed to consumer processes as `TF_VAR_*` environment variables (outputs sharing) |
| Removing a configuration | the next apply destroys (revokes) the credential | destroy the stack explicitly, then `sync_stacks.py --prune`; CI fails while an orphaned stack exists |
| Files in git | the configurations | the configurations plus generated stacks (5 files per credential / unit); concurrent branches can conflict in a `stack.tm.hcl` (resolve by regenerating) |
| Maturity of what it relies on | stable OpenTofu features (`convert()` needs 1.13) | experimental Terramate outputs sharing |
| Tests in CI | engine end-to-end (duplicate check, rotation runs), extension unit tests with mock providers, example validation | the same, plus phase-arithmetic unit tests, sync-script unit tests, an end-to-end check that consumers receive the rotated credential, and a check that applying with mock credentials is refused |

## Which one to use

- **`master`** if you have up to a few dozen credentials, want a single tool, and value seeing the full effect of a rotation in one plan.
- **`implementation/terramate`** if you have many credentials or several teams contributing configurations or extensions, need failures to stay contained, or want runs limited to what a change affects. Accept the extra tooling and the experimental outputs sharing.

## Switching between them

Configurations and extensions carry over unchanged. State does not: the two engines use different resource addresses and state layouts, and there is no automated migration. Switching means importing the existing credentials into the new layout or letting the new engine create fresh ones (they rotate anyway). Details of the stack design: [`docs/stacks.md`](https://github.com/aklakina/gaean-key/blob/implementation/terramate/docs/stacks.md) and the [Terramate ADR](https://github.com/aklakina/gaean-key/blob/implementation/terramate/docs/adr/20261122-run-the-engine-on-terramate-stacks.md) on the `implementation/terramate` branch.
