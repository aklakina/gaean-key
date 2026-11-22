# Pure phase arithmetic of the dual-phase rotation (no resources, so it can be unit tested).
# With expiry E, rotation window W and cycle start t0:
#   phase 1 exists in [t0, t0 + E) and [t0 + 2E - W, t0 + 2E)
#   phase 2 exists in [t0 + E - W, t0 + 2E)
#   consumers get phase 2 in [t0 + E - W, t0 + 2E - W), phase 1 otherwise

variable "start_time" {
  description = "Cycle start t0 (RFC 3339)."
  type        = string
}

variable "now" {
  description = "Current time (RFC 3339), plantimestamp() in the engine."
  type        = string
}

variable "expiry_minutes" {
  type = number
}

variable "rotation_window_minutes" {
  type = number
}

locals {
  e = var.expiry_minutes
  w = var.rotation_window_minutes

  after_e_minus_w  = timecmp(var.now, timeadd(var.start_time, "${local.e - local.w}m")) >= 0
  before_e         = timecmp(var.now, timeadd(var.start_time, "${local.e}m")) < 0
  after_2e_minus_w = timecmp(var.now, timeadd(var.start_time, "${2 * local.e - local.w}m")) >= 0
  before_2e        = timecmp(var.now, timeadd(var.start_time, "${2 * local.e}m")) < 0
}

output "phase1_active" {
  value = local.before_e || local.after_2e_minus_w
}

output "phase2_active" {
  value = local.after_e_minus_w && local.before_2e
}

output "use_phase2" {
  value = local.after_e_minus_w && !local.after_2e_minus_w
}
