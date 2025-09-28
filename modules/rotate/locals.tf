locals {
  flattened_configs = merge([
    for k, v in var.configs : {
      for kk, vv in v : "${k}_${kk}" => vv
    }
  ]...)
}

resource "time_rotating" "rotate" {
  # the rotation is independent for each config. We need to create a flattened map from the map of maps in the configs variable
  for_each = local.flattened_configs
  rotation_minutes = provider::time::duration_parse(each.value["validity_duration"]).minutes * 2
}

resource "terraform_data" "timer" {
  for_each = local.flattened_configs
  input = plantimestamp()
  triggers_replace = time_rotating.rotate[each.key].id
  lifecycle {
    ignore_changes = [input]
  }
}

locals {
  # This creates a 2 phased rotation system. Phase 1 is from [0, expiry] and [expiry*2 - rotation_window, expiry*2]. Phase 2 is from [expiry - rotation_window, expiry*2]
  # This results in an overlap between phase 1 and phase 2 both at the beginning of phase 2 and at the end of phase 2.
  phases = {
    1 = {
      for k, v in var.configs : k => {
        for kk, vv in v : kk => merge(vv, {
          decommissioning = timecmp(
            plantimestamp(),
            timeadd(
              timeadd(
                terraform_data.timer["${k}_${kk}"].input,
                "${provider::time::duration_parse(vv["validity_duration"]).seconds * 2}s"
              ),
              "-${try(vv["rotation_window_duration"], "0s")}"
            )
          ) >= 0 && timecmp(
            plantimestamp(),
            timeadd(
              terraform_data.timer["${k}_${kk}"].input,
              vv["validity_duration"]
            )
          ) <= 0
        })
        if timecmp(
          plantimestamp(),
          timeadd(
            terraform_data.timer["${k}_${kk}"].input,
            vv["validity_duration"]
          )
        ) <= 0 || timecmp(
          plantimestamp(),
          timeadd(
            timeadd(
              terraform_data.timer["${k}_${kk}"].input,
              "${provider::time::duration_parse(vv["validity_duration"]).seconds * 2}s"
            ),
            "-${try(vv["rotation_window_duration"], "0s")}"
          )
        ) >= 0 # Any secret which is in [0, expiry] or [expiry*2 - rotation_window, expiry*2] is in phase 1
      }
    },
    2 = {
      for k, v in var.configs : k => {
        for kk, vv in v : kk => merge(vv, {
          decommissioning = timecmp(
            plantimestamp(),
            timeadd(
              timeadd(
                terraform_data.timer["${k}_${kk}"].input,
                "${provider::time::duration_parse(vv["validity_duration"]).seconds * 2}s"
              ),
              "-${try(vv["rotation_window_duration"], "0s")}"
            )
          ) >= 0
        })
        if timecmp(
          plantimestamp(),
          timeadd(
            timeadd(
              terraform_data.timer["${k}_${kk}"].input,
              vv["validity_duration"]
            ),
            "-${try(vv["rotation_window_duration"], "0s")}"
          )
        ) >= 0 # Any secret which is in [expiry - rotation_window, expiry * 2] is in phase 2
      }
    }
  }
}