# Unit test of this extension component against a mock AzureRM provider.

mock_provider "azurerm" {}

variables {
  secrets = {
    azuread = {
      deployer = { username = "11111111-1111-1111-1111-111111111111", secret = "client-secret" }
    }
  }
}

run "stores_secret_and_username" {
  command = apply

  variables {
    configurations = {
      deployer = {
        key_vault_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/kv"
        name          = "deployer-client-secret"
        username_name = "deployer-client-id"
        tags          = { team = "platform" }
        config_file   = "configurations/azure_keyvault/deployment/secret/deployer.yml"
        secret        = { service = "azuread", id = "deployer" }
      }
    }
  }

  assert {
    condition     = azurerm_key_vault_secret.this["deployer/secret"].value == "client-secret"
    error_message = "name must receive the credential's secret."
  }

  assert {
    condition     = azurerm_key_vault_secret.this["deployer/username"].value == "11111111-1111-1111-1111-111111111111"
    error_message = "username_name must receive the credential's username."
  }

  assert {
    condition = azurerm_key_vault_secret.this["deployer/secret"].tags == tomap({
      team          = "platform"
      "managed-by"  = "gaean-key"
      "config-file" = "configurations/azure_keyvault/deployment/secret/deployer.yml"
    })
    error_message = "Tags must keep the configured ones and add managed-by / config-file."
  }
}

run "rejects_unknown_credential" {
  command = plan

  variables {
    configurations = {
      dangling = {
        key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/kv"
        name         = "missing"
        secret       = { service = "azuread", id = "does-not-exist" }
      }
    }
  }

  expect_failures = [azurerm_key_vault_secret.this]
}
