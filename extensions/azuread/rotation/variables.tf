variable "configurations" {
  description = "Rotation configs keyed by id. Each adds a client secret to an existing Entra ID (Azure AD) application."
  type = map(object({
    # Application (client) ID of the app registration.
    client_id = string
    # Display name of the client secret; defaults to "gaean-key <id> <creation date>".
    display_name = optional(string)
    # Passed through from the rotation config. The secret's end_date is creation +
    # expires_in + rotation_window (the time a phase exists), see main.tf.
    expires_in      = string
    rotation_window = optional(string)
  }))
}
