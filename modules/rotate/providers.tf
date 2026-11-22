# Provider instances of the rotation extensions, one per service, created only while the service is
# enabled: while configurations/<service>/ contains any .yml file (a config or service.yml). A
# provider that is never instantiated is never configured, so you only need credentials for the
# services you use. Credentials come from the providers' standard environment variables; optional
# non-secret settings from var.provider_settings.
#
# Retiring a service: delete its configs and apply (destroys the credentials), then delete its
# service.yml. Deleting everything at once removes the provider before the credentials can be
# destroyed.
#
# The set is computed here with fileset() (not passed in from load_configs) because provider
# for_each must be known during OpenTofu's static evaluation, which can't read module outputs.

locals {
  enabled_services = toset([
    for f in fileset("${path.module}/../../configurations", "*/**/*.yml") : split("/", f)[0]
  ])
  provider_instances = {
    for service in ["aws", "azuread", "gitlab"] :
    service => contains(local.enabled_services, service) ? toset(["default"]) : toset([])
  }
}

provider "aws" {
  alias    = "rotation"
  for_each = local.provider_instances["aws"]

  region  = var.provider_settings.aws.region
  profile = var.provider_settings.aws.profile
}

provider "azuread" {
  alias    = "rotation"
  for_each = local.provider_instances["azuread"]

  tenant_id = var.provider_settings.azuread.tenant_id
}

provider "gitlab" {
  alias    = "rotation"
  for_each = local.provider_instances["gitlab"]

  base_url = var.provider_settings.gitlab.base_url
}
