variable "configs" {
  description = "Flat map of rotation configs. Keys are '<service>/<path>' (e.g. 'test_service/dynamic-cred'), values are the config data."
  validation {
    condition = alltrue([
      for path, config in var.configs : can(config.expires_in)
    ])
    error_message = "expires_in must be provided in each rotation configuration."
  }
  validation {
    # expires_in and the optional rotation_window must be parsable durations (templates such as "${30*24}h" are allowed)
    condition = alltrue([
      for path, config in var.configs : (
        can(provider::time::duration_parse(templatestring(config.expires_in, {})))
        && (
          try(config.rotation_window, null) == null
          || can(provider::time::duration_parse(templatestring(config.rotation_window, {})))
        )
      )
    ])
    error_message = "expires_in and the optional rotation_window must be durations parsable by provider::time::duration_parse (e.g. \"720h\" or \"$${30*24}h\")."
  }
  validation {
    condition = alltrue([
      for path, config in var.configs : (
        try(config.rotation_window, null) == null
        || try(
          provider::time::duration_parse(templatestring(config.expires_in, {})).seconds >
          provider::time::duration_parse(templatestring(config.rotation_window, {})).seconds,
          false
        )
      )
    ])
    error_message = "rotation_window must be shorter than expires_in."
  }
}

variable "provider_settings" {
  description = "Non-secret provider settings, see the root variable of the same name."
}

variable "secrets" {
  description = "Credentials from the Get stage (service => id => {username, secret}), so rotations can depend on other credentials."
  sensitive   = true
}
