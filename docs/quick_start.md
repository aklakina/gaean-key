# Quick Start

## Prerequisites

- Terraform 1.11+
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
### Run Terraform commands from repository root
```bash
terraform init [-upgrade]
terraform plan -var-file ./creds.tfvars
terraform apply -var-file ./creds.tfvars
```