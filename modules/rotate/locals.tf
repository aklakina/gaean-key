locals {
  all_configs = var.configs

  expiry_minutes = {
    for key, config in local.all_configs :
    key => floor(provider::time::duration_parse(templatestring(config.expires_in, {})).minutes)
  }
  rotation_window_minutes = {
    for key, config in local.all_configs :
    key => try(config.rotation_window, null) != null ? floor(provider::time::duration_parse(templatestring(config.rotation_window, {})).minutes) : floor(local.expiry_minutes[key] * 0.2)
  }
}

locals {
  start_times = {
    for key, _ in local.all_configs : key => terraform_data.deterministic_time[key].input.time
  }

  # Secret id as seen by consumers: config path without the service prefix. Derived from
  # the config keys only, so it is known at plan time.
  secret_ids = {
    for key, _ in local.all_configs :
    key => join("/", slice(split("/", key), 1, length(split("/", key))))
  }

  # Which phase's credential is the active one (phase2 in [t0 + E - W, t0 + 2E - W)).
  use_phase2 = {
    for key, _ in local.all_configs : key => (
      timecmp(plantimestamp(), timeadd(local.start_times[key], "${local.expiry_minutes[key] - local.rotation_window_minutes[key]}m")) >= 0
      &&
      timecmp(plantimestamp(), timeadd(local.start_times[key], "${2 * local.expiry_minutes[key] - local.rotation_window_minutes[key]}m")) < 0
    )
  }

  flat_phases = {
    # Phase 1: Active [t0, t0 + E) AND [t0 + 2E - W, t0 + 2E)
    phase1 = {
      for key, value in local.all_configs :
      key => value if(
        timecmp(plantimestamp(), timeadd(local.start_times[key], "${local.expiry_minutes[key]}m")) < 0
        ) || (
        timecmp(plantimestamp(), timeadd(local.start_times[key], "${2 * local.expiry_minutes[key] - local.rotation_window_minutes[key]}m")) >= 0
      )
    }

    # Phase 2: Active [t0 + E - W, t0 + 2E)
    phase2 = {
      for key, value in local.all_configs :
      key => value if(
        # t >= t0 + expiry - rotation_window
        timecmp(plantimestamp(), timeadd(local.start_times[key], "${local.expiry_minutes[key] - local.rotation_window_minutes[key]}m")) >= 0
        ) && (
        # t < t0 + 2*expiry
        timecmp(plantimestamp(), timeadd(local.start_times[key], "${2 * local.expiry_minutes[key]}m")) < 0
      )
    }
  }
}

# Rebuild folder hierarchy for phases
data "jinja_template" "build_hierarchy" {
  for_each = local.flat_phases
  context {
    type = "yaml"
    data = yamlencode({
      flat_configs = [
        for key, config in each.value : {
          service = split("/", key)[0]
          path_segments = slice(
            split("/", key),
            1,
            length(split("/", key)) - 1
          )
          config_name = element(split("/", key), -1)
          config      = config
        }
      ]
    })
  }
  source {
    template  = file("${path.module}/../config_processor.jinja2")
    directory = path.module
  }
}

locals {
  phase1 = jsondecode(data.jinja_template.build_hierarchy["phase1"].result)
  phase2 = jsondecode(data.jinja_template.build_hierarchy["phase2"].result)
}