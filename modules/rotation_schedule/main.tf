# Timers of the dual-phase rotation of one credential (one rotation stack = one credential).
# The resources use create_before_destroy; see docs/adr/20260303-fix-circular-dependency-in-rotation-lifecycle.md.

locals {
  expiry_minutes = floor(provider::time::duration_parse(templatestring(var.expires_in, {})).minutes)
  rotation_window_minutes = (
    var.rotation_window != null
    ? floor(provider::time::duration_parse(templatestring(var.rotation_window, {})).minutes)
    : floor(local.expiry_minutes * 0.2)
  )
}

resource "terraform_data" "expiry" {
  input = {
    expiry = local.expiry_minutes
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "time_rotating" "cycle_timer" {
  rotation_minutes = floor(2 * local.expiry_minutes)

  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      terraform_data.expiry
    ]
  }
}

resource "terraform_data" "deterministic_time" {
  input = {
    time = plantimestamp()
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      input
    ]
    replace_triggered_by = [
      time_rotating.cycle_timer
    ]
  }
}

module "phases" {
  source = "./phases"

  start_time              = terraform_data.deterministic_time.input.time
  now                     = plantimestamp()
  expiry_minutes          = local.expiry_minutes
  rotation_window_minutes = local.rotation_window_minutes
}
