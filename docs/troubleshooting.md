# Troubleshooting

## Common Issues

1. **Extension not found**
	- Verify extension exists in `extensions/` directory
	- Check extension structure follows required format
2. **Configuration not loading**
	- Verify YAML files are placed in the correct `configurations/<service>/<stage>/` directory and end in `.yml`
	- Ensure YAML syntax is valid
	- Check that the `service.yml` (if used) does not conflict with individual config values (file values win)
3. **Extension not linked properly**
	- Verify that you have edited the `modules/<component>/main.tf` (for rotations: the `phase1`/`phase2` pair in `modules/rotate/modules.tf`) properly to add the link to your new extension
4. **Engine reports no secret exists with referenced service and id**
	- In case of new extension, verify that you have also linked the output of your extension in `modules/<component>/outputs.tf` properly
	- In case of existing extension, verify that the configuration actually exists and which component outputs it
	- Double-check the `secret.service` / `secret.id` values in the consumer configuration
5. **Conflict detected: the same credential ID exists in both get and rotation**
	- A `service`/`id` can either be retrieved or rotated, not both. Rename or remove one of the configurations
6. **Rotation not triggering**
	- Verify the `expires_in` property is defined in the rotation configuration
	- Check the `time_rotating` resource state — it may need to be tainted to force a rotation
	- Ensure the `rotation_window` (if specified) is shorter than `expires_in`
	- Rotation only happens when OpenTofu runs: check that the scheduled `tofu apply` actually runs
7. **"Provider instance not present" after removing a service**
	- The service's whole folder was deleted while its credentials still exist, so its provider is gone before they can be destroyed
	- Restore `configurations/<service>/service.yml` (any `.yml` in the folder re-enables the provider), apply, then delete it
8. **Provider credential errors for a service you don't use**
	- A provider is configured as soon as `configurations/<service>/` contains any `.yml` file; remove the folder (after its credentials are destroyed, see above)

## Useful OpenTofu snippet for debug

```hcl
resource "terraform_data" "debug" {
	inputs = {
		<some human readable key> = <STRINGIFIED data to print>
	}
}
```
