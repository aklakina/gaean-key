# Provider instances of the deployment/store extensions, gated per service exactly like
# modules/rotate/providers.tf (see there): created only while configurations/<service>/ contains
# a .yml file. Credentials come from the providers' standard environment variables; optional
# non-secret settings from var.provider_settings.

locals {
  enabled_services = toset([
    for f in fileset("${path.module}/../../configurations", "*/**/*.yml") : split("/", f)[0]
  ])
  provider_instances = {
    for service in ["github", "azure_keyvault"] :
    service => contains(local.enabled_services, service) ? toset(["default"]) : toset([])
  }
}

provider "github" {
  alias    = "deployment"
  for_each = local.provider_instances["github"]

  owner    = var.provider_settings.github.owner
  base_url = var.provider_settings.github.base_url
}

provider "azurerm" {
  alias    = "deployment"
  for_each = local.provider_instances["azure_keyvault"]

  subscription_id = var.provider_settings.azurerm.subscription_id
  tenant_id       = var.provider_settings.azurerm.tenant_id
  features {}
}
