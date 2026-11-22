variable "configurations" {
  description = "Rotation configs keyed by id. Each adds a client secret to an existing Entra ID (Azure AD) application."
  type = map(object({
    # Application (client) ID of the app registration.
    client_id = string
    # Display name of the client secret; defaults to "gaean-key <id> <creation date>".
    display_name = optional(string)
    # Passed through from the rotation config; used as the lifetime (end_date) of the secret.
    expires_in = string
  }))
}
