variable "configs" {
  type = map(map(any))
  validation {
    # validity_duration must be set
    condition = alltrue([
      for k, v in var.configs : alltrue([
        for kk, vv in v : can(vv["validity_duration"])
      ])
    ])
    error_message = "Each rotation config must have 'validity_duration' set."
  }
  validation {
    # Can parse both validity_duration and rotation_window_duration (if set) with duration_parse
    condition = alltrue([
      for k, v in var.configs : alltrue([
        for kk, vv in v :
        (
          can(provider::time::duration_parse(vv["validity_duration"]))
          && (
            !can(vv["rotation_window_duration"])
            || can(provider::time::duration_parse(vv["rotation_window_duration"]))
          )
        )
      ])
    ])
    error_message = "Each rotation config must have 'validity_duration' and optional 'rotation_window_duration' parsable by duration_parse."
  }
  validation {
    # The validity_duration must be greater than the rotation_window_duration
    condition = alltrue([
      for k, v in var.configs : alltrue([
        for kk, vv in v : (
          provider::time::duration_parse(try(vv["validity_duration"], "0s")).seconds >
          provider::time::duration_parse(try(vv["rotation_window_duration"], "0s")).seconds
        )
      ])
    ])
    error_message = "Each rotation config must have 'validity_duration' greater than 'rotation_window_duration'."
  }
}
