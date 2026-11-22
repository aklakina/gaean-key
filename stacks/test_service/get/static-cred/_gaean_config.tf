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
}
