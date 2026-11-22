// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  config    = merge(local.service_defaults, yamldecode(file("${local.gaean_root}/configurations/test_service/get/static-cred.yml")))
  secret_id = "static-cred"
}
module "extension" {
  configurations = {
    (local.secret_id) = local.config
  }
  source = "../../../../extensions/test_service/get"
}
locals {
  credential = module.extension.secret[local.secret_id]
}
