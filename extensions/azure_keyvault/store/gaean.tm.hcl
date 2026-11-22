# Provider configuration of every stack running this component (imported by scripts/sync_stacks.py).
# Credentials come from the provider's environment variables (ARM_*); optional non-secret settings
# from the Terramate global provider_settings.azurerm (see docs/stacks.md#provider-configuration).

globals {
  # merged into the stack's required_providers by stacks/engine.tm.hcl
  gaean_required_providers = {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

generate_hcl "_gaean_providers.tf" {
  content {
    provider "azurerm" {
      subscription_id = tm_try(global.provider_settings.azurerm.subscription_id, null)
      tenant_id       = tm_try(global.provider_settings.azurerm.tenant_id, null)
      features {}
    }
  }
}
