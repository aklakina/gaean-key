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
    # Passed through from the rotation config. The token's expires_at is the date of creation +
    # expires_in + rotation_window (the time a phase exists), rounded up, see main.tf.
    expires_in      = string
    rotation_window = optional(string)
  }))

  validation {
    condition     = alltrue([for k, v in var.configurations : (v.project == null) != (v.group == null)])
    error_message = "Each GitLab token config must set exactly one of 'project' and 'group'."
  }
}
