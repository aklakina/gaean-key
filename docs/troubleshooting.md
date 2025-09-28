# Troubleshooting

## Common Issues

1. **Extension not found**
	- Verify extension exists in `extensions/` directory
	- Check extension structure follows required format
2. Extension not linked properly
	- Verify that you have edited the `modules/<component>/main.tf` properly to add the link to your new extension.
3. Engine reports no secret exists with referenced service and id
	- In case of new extension, verify that you have also linked the output of your extension in `modules/<component>/outputs.tf` properly.
	- In case of existing extension, verify that the configuration actually exists and which component outputs it.
## Useful terraform snippet for debug

```hcl
resource "terraform_data" "debug" {
	inputs = {
		<some human readable key> = <STRINGIFIED data to print>
	}
}
```