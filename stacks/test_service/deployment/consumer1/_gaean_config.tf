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
  secret_refs = {
    cred_test_service_dynamic_cred_9e40e3 = {
      id      = "dynamic-cred"
      service = "test_service"
    }
    cred_test_service_static_cred_4b4968 = {
      id      = "static-cred"
      service = "test_service"
    }
  }
  secret_values = {
    cred_test_service_dynamic_cred_9e40e3 = var.cred_test_service_dynamic_cred_9e40e3
    cred_test_service_static_cred_4b4968  = var.cred_test_service_static_cred_4b4968
  }
  secrets = merge(local.placeholder_secrets, { for service in distinct([for ref in values(local.secret_refs) : ref.service]) : service => { for name, ref in local.secret_refs : ref.id => local.secret_values[name] if ref.service == service } })
  service_defaults = merge({}, [
  ]...)
}
