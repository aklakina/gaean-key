# Troubleshooting

## Common Issues

1. **`sync_stacks.py`: the extension component does not exist / declares none of the variables or outputs**
	- Verify the extension exists in `extensions/<service>/<stage>/` (the folder names must match the configuration folders)
	- Check the component follows the [contract](./extension_development.md#extension-requirements): a `configurations`/`configs`/`configuration` variable, a `secret`/`secrets` output for providers, a `secrets` variable for deployments
2. **Configuration not loading**
	- Verify YAML files are placed in the correct `configurations/<service>/<stage>/` directory and end in `.yml`
	- Ensure YAML syntax is valid
	- Check that the `service.yml` (if used) does not conflict with individual config values (file values win)
	- Rerun `python scripts/sync_stacks.py` and `terramate generate` after adding or moving files
3. **`sync_stacks.py`: no get or rotation config produces `<service>/<id>`**
	- Verify that the configuration actually exists and is enabled (`.yml`, not `.yml.old`)
	- The id is the file path below `get/` or `rotation/` without `.yml` (e.g. `team/token` for `rotation/team/token.yml`)
	- Double-check the `secret.service` / `secret.id` values in the consumer configuration
4. **Conflict: credential is produced by both ... A service/id can either be retrieved or rotated, not both**
	- Rename or remove one of the configurations
5. **Terramate: "repository has untracked files" / "uncommitted changes" / "outdated code"**
	- Commit the stacks and generated files, or run `terramate generate`; for local experiments pass `-X` (`--disable-safeguards=all`)
6. **A consumer has the mock credential (`mock`/`mock`) or an old one**
	- `--enable-sharing` was missing, or the producer stack had not been applied yet when the consumer ran. Apply the producer and its dependents: `terramate run --chdir <producer stack> --include-all-dependents --enable-sharing -- tofu apply`
	- `--mock-on-fail` only belongs to `init`/`plan`/`destroy`. Applying with mock credentials fails with "Refusing to apply with mock credentials": apply the producer stacks first (or the whole graph in order with `terramate run --enable-sharing -- tofu apply`)
7. **Rotation not triggering**
	- Rotation is time driven: make sure the rotation stacks are applied on a schedule (`--tags rotation --include-all-dependents`), `--changed` alone does not select them
	- Check the stack's `schedule` output (`tofu -chdir=stacks/<service>/rotation/<id> output schedule`)
	- Check the `time_rotating` resource state — it may need to be tainted (`module.schedule.time_rotating.cycle_timer`) to force a rotation
	- Ensure the `rotation_window` (if specified) is shorter than `expires_in`
8. **`sync_stacks.py` reports an orphan**
	- Its configuration was removed: destroy the stack, then run `python scripts/sync_stacks.py --prune` (see [Quick Start](./quick_start.md#removing-a-configuration))
	- If the configuration is already gone, the stack can still be destroyed: its generated code reads the YAML, so restore the file (e.g. `git checkout <rev> -- <file>`), destroy, delete it again
9. **Provider "requires explicit configuration" / authentication errors although settings are set**
	- The stack's root module must declare the provider's source: the extension's `gaean.tm.hcl` sets `gaean_required_providers` (see [Stacks](./stacks.md#provider-configuration)); without it e.g. `provider "gitlab"` configures `hashicorp/gitlab` and the extension gets an unconfigured `gitlabhq/gitlab`. `tofu providers` in the stack should show a single entry per provider
	- Run `terramate generate` after changing `provider_settings` globals or a `gaean.tm.hcl`
	- Credentials come from the provider's environment variables only; check they are set in the job that runs `terramate run`

## Useful OpenTofu snippet for debug

```hcl
resource "terraform_data" "debug" {
	inputs = {
		<some human readable key> = <STRINGIFIED data to print>
	}
}
```

To inspect what the engine generated for a stack, read its `_gaean_*.tf` files; `terramate debug show globals` shows the `gaean` globals of every stack.
