// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  gaean_root = "${path.module}/../../../.."
  placeholder_secrets = {
    TBD = {
      TBD = {
        secret   = "TBD"
        username = "TBD"
      }
    }
    none = {
      none = {
        secret   = "none"
        username = "none"
      }
    }
  }
  secret_refs   = {}
  secret_values = {}
  secrets       = merge(local.placeholder_secrets, { for service in distinct([for ref in values(local.secret_refs) : ref.service]) : service => { for name, ref in local.secret_refs : ref.id => local.secret_values[name] if ref.service == service } })
  service_defaults = merge({}, [
  ]...)
  uses_mock_credentials = anytrue([for v in values(local.secret_values) : nonsensitive(try(v.gaean_mock, false))])
}
check "mock_credentials" {
  assert {
    condition     = !local.uses_mock_credentials
    error_message = "Planned with mock credentials (--mock-on-fail): a producer stack this stack reads from has no state yet. This plan is a preview only; applying it will be refused. Apply the producer stacks first."
  }
}
resource "terraform_data" "mock_guard" {
  count = local.uses_mock_credentials ? 1 : 0
  lifecycle {
    precondition {
      condition     = !local.uses_mock_credentials || timestamp() == ""
      error_message = "Refusing to apply with mock credentials (--mock-on-fail): apply the producer stacks first, then this stack without --mock-on-fail."
    }
  }
}
