resource "terraform_data" "expiry" {
  for_each = local.all_configs

  input = {
    expiry = local.expiry_minutes[each.key]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "time_rotating" "cycle_timer" {
  for_each         = local.all_configs
  rotation_minutes = floor(2 * local.expiry_minutes[each.key])

  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      terraform_data.expiry[each.key]
    ]
  }
}

resource "terraform_data" "deterministic_time" {
  for_each = local.all_configs

  input = {
    time = plantimestamp()
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      input
    ]
    replace_triggered_by = [
      time_rotating.cycle_timer[each.key]
    ]
  }
}
