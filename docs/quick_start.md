# Quick Start

## Prerequisites

- [OpenTofu](https://opentofu.org/) 1.13+ (the engine uses the OpenTofu-only `convert()` function)
- [Credentials for services defined](#defining-service-credentials)

## Basic Usage

### Defining service credentials

Create the credentials file under the name `creds.tfvars` in the root of the repository and define the following object:

```hcl
login_credentials = {
  <service_name> = {
        <service specific credential input keys and values>
  }
}
```
Exact variable definition can be seen in the [./versions.tf](../versions.tf) file
### Run OpenTofu commands from repository root
```bash
tofu init [-upgrade]
tofu plan -var-file ./creds.tfvars
tofu apply -var-file ./creds.tfvars
```