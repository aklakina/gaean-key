# Unit test of this extension component against a mock Entra ID provider.

mock_provider "azuread" {
  mock_data "azuread_application" {
    defaults = {
      id = "/applications/00000000-0000-0000-0000-000000000001"
    }
  }
}

run "adds_client_secret_with_expiry" {
  command = apply

  variables {
    configurations = {
      deployer = {
        client_id  = "11111111-1111-1111-1111-111111111111"
        expires_in = "$${30*24}h"
      }
      explicit-window = {
        client_id       = "22222222-2222-2222-2222-222222222222"
        expires_in      = "720h"
        rotation_window = "48h"
      }
    }
  }

  assert {
    condition     = azuread_application_password.this["deployer"].application_id == "/applications/00000000-0000-0000-0000-000000000001"
    error_message = "The secret must be added to the application looked up by client id."
  }

  assert {
    # 720h + the default rotation window (20% = 144h): the secret must stay valid as long as its
    # phase exists, or the overlap between the old and the new secret is lost.
    condition     = azuread_application_password.this["deployer"].end_date == timeadd(time_static.created["deployer"].rfc3339, "864h")
    error_message = "end_date must be creation time + expires_in + default rotation window (templates evaluated)."
  }

  assert {
    condition     = azuread_application_password.this["explicit-window"].end_date == timeadd(time_static.created["explicit-window"].rfc3339, "768h")
    error_message = "end_date must be creation time + expires_in + rotation_window."
  }

  assert {
    condition     = startswith(azuread_application_password.this["deployer"].display_name, "gaean-key deployer ")
    error_message = "Default display name must identify the config."
  }

  assert {
    condition     = output.secret["deployer"].username == "11111111-1111-1111-1111-111111111111"
    error_message = "username must be the client id."
  }

  assert {
    condition     = output.secret["deployer"].secret == azuread_application_password.this["deployer"].value
    error_message = "secret must be the client secret value."
  }
}
