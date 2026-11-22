variable "configurations" {
  description = "Rotation configs keyed by id. Each creates a project or group access token."
  type = map(object({
    # Exactly one of project (ID or full path) and group (ID or full path).
    project = optional(string)
    group   = optional(string)
    # Token name; defaults to "gaean-key-<id>". Also used as the username of the credential.
    name         = optional(string)
    description  = optional(string, "Managed by Gaean Key")
    scopes       = list(string)
    access_level = optional(string, "developer")
    # Passed through from the rotation config.
    expires_in      = string
    rotation_window = optional(string)
  }))

  validation {
    condition     = alltrue([for k, v in var.configurations : (v.project == null) != (v.group == null)])
    error_message = "Each GitLab token config must set exactly one of 'project' and 'group'."
  }

  validation {
    # GitLab expiry dates have day precision (the token expires at 00:00 UTC of expires_at), so the
    # overlap must be at least a day or the old token may expire before consumers switch over.
    condition = alltrue([
      for k, v in var.configurations : (
        v.rotation_window != null
        ? provider::time::duration_parse(templatestring(v.rotation_window, {})).hours
        : provider::time::duration_parse(templatestring(v.expires_in, {})).hours * 0.2
      ) >= 24
    ])
    error_message = "GitLab tokens expire with day precision: the rotation window (default 20% of expires_in) must be at least 24h."
  }
}
