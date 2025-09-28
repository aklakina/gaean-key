module "load_configs" {
  source = "./modules/load_configs"
}

module "get_credentials" {
  source = "./modules/get"

  configs = module.load_configs.configs["get"]
}

module "rotation" {
  source = "./modules/rotate"

  configs = module.load_configs.configs["rotation"]
}

locals {
  duplicate_ids = flatten([
    for service in distinct(concat(keys(module.get_credentials.credentials), keys(module.rotation.credentials))) : [
      for id in keys(lookup(module.get_credentials.credentials, service, {})) :
      "${service}.${id}" if contains(keys(lookup(module.rotation.credentials, service, {})), id)
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
      condition = length(local.duplicate_ids) == 0
      error_message = "Conflict detected: The same credential ID exists in both get and rotation modules for the same service."
    }
  }
  depends_on = [
    module.get_credentials,
    module.rotation
  ]
}

locals {
  merged_credentials = {
    for service in distinct(concat(keys(module.get_credentials.credentials), keys(module.rotation.credentials))) :
    service => merge(
      lookup(module.get_credentials.credentials, service, {}),
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