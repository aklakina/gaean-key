// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  config    = merge(local.service_defaults, yamldecode(file("${local.gaean_root}/configurations/test_service/rotation/dynamic-cred.yml")))
  secret_id = "dynamic-cred"
}
module "schedule" {
  expires_in      = local.config.expires_in
  rotation_window = try(local.config.rotation_window, null)
  source          = "../../../../modules/rotation_schedule"
}
module "phase1" {
  configurations = {
    (local.secret_id) = local.config
  }
  count  = module.schedule.phase1_active ? 1 : 0
  source = "../../../../extensions/test_service/rotation"
}
module "phase2" {
  configurations = {
    (local.secret_id) = local.config
  }
  count  = module.schedule.phase2_active ? 1 : 0
  source = "../../../../extensions/test_service/rotation"
}
locals {
  active_phase = module.schedule.use_phase2 ? module.phase2 : module.phase1
  credential   = local.active_phase[0].secret[local.secret_id]
}
output "schedule" {
  description = "Rotation schedule of the credential."
  value = {
    start_time    = module.schedule.start_time
    phase1_active = module.schedule.phase1_active
    phase2_active = module.schedule.phase2_active
    use_phase2    = module.schedule.use_phase2
  }
}
