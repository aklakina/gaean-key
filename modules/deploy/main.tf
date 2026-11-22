module "test_service" {
  source   = "../../extensions/test_service/deployment"
  for_each = lookup(var.configs, "test_service", {})

  configurations = each.value
  secrets        = var.secrets
}

locals {
  github_actions_secrets = lookup(lookup(var.configs, "github", {}), "actions_secret", {})
  azure_keyvault_secrets = lookup(lookup(var.configs, "azure_keyvault", {}), "secret", {})
}

# Extensions with a provider are instantiated per provider instance ("default"), but only while
# they have configs: a subset of the provider's instances, so the provider outlives the resources
# when the last config is removed (as long as the service's service.yml stays).

module "github_actions_secret" {
  source   = "../../extensions/github/deployment"
  for_each = length(local.github_actions_secrets) > 0 ? local.provider_instances["github"] : toset([])

  configurations = local.github_actions_secrets
  secrets        = var.secrets
  providers = {
    github = github.deployment[each.key]
  }
}

module "azure_keyvault_secret" {
  source   = "../../extensions/azure_keyvault/store"
  for_each = length(local.azure_keyvault_secrets) > 0 ? local.provider_instances["azure_keyvault"] : toset([])

  configurations = local.azure_keyvault_secrets
  secrets        = var.secrets
  providers = {
    azurerm = azurerm.deployment[each.key]
  }
}
