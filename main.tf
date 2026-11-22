module "load_configs" {
  source = "./modules/load_configs"
}

module "get_credentials" {
  source = "./modules/get"

  configs = module.load_configs.configs["get"]
}

locals {
  # Placeholder credentials consumers can reference (secret: {service: none, id: none})
  # before the real credential exists.
  credentials = merge(
    module.get_credentials.credentials,
    {
      none = {
        none = {
          username = "none"
          secret   = "none"
        }
      }
      TBD = {
        TBD = {
          username = "TBD"
          secret   = "TBD"
        }
      }
    }
  )
}

module "rotation" {
  source = "./modules/rotate"

  configs = module.load_configs.configs["rotation"]

  # Retrieved credentials, so a rotation can depend on another credential.
  secrets = local.credentials
}

locals {
  # Service and id sets are plan-time known; only the values are sensitive.
  get_ids      = { for service, creds in nonsensitive({ for s, c in local.credentials : s => keys(c) }) : service => creds }
  rotation_ids = { for service, creds in nonsensitive({ for s, c in module.rotation.credentials : s => keys(c) }) : service => creds }

  duplicate_ids = flatten([
    for service, ids in local.get_ids : [
      for id in ids : "${service}.${id}" if contains(lookup(local.rotation_ids, service, []), id)
    ]
  ])
}

resource "terraform_data" "conflict_check" {
  count = length(local.duplicate_ids) > 0 ? 1 : 0
  input = {
    duplicate_ids = local.duplicate_ids
  }
  lifecycle {
    postcondition {
      condition     = length(local.duplicate_ids) == 0
      error_message = "Conflict detected: The same credential ID exists in both get and rotation modules for the same service."
    }
  }
  depends_on = [
    module.get_credentials,
    module.rotation
  ]
}

locals {
  # Merged per service, so a service can both retrieve and rotate credentials.
  merged_credentials = {
    for service in distinct(concat(keys(local.get_ids), keys(local.rotation_ids))) :
    service => merge(
      lookup(local.credentials, service, {}),
      lookup(module.rotation.credentials, service, {})
    )
  }
}

module "deployment" {
  source = "./modules/deploy"

  secrets = local.merged_credentials
  configs = module.load_configs.configs["deployment"]
  depends_on = [
    terraform_data.conflict_check
  ]
}
