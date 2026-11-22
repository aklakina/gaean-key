variable "configurations" {
  description = "GitHub Actions secret configs keyed by name (configurations/github/deployment/actions_secret/<name>.yml)."
  type = map(object({
    # Repository name (the owner comes from the provider, e.g. GITHUB_OWNER).
    repository = string
    # Environment name; when set, environment secrets are created instead of repository secrets.
    environment = optional(string)
    # Actions secret receiving the credential's secret.
    secret_name = string
    # Optional Actions secret receiving the credential's username.
    username_secret_name = optional(string)
    secret = object({
      service = string
      id      = string
    })
  }))
}

variable "secrets" {
  description = "All credentials: service => id => { username, secret }."
  sensitive   = true
}
