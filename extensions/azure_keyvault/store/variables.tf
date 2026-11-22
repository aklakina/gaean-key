variable "configurations" {
  description = "Key Vault secret configs keyed by name (configurations/azure_keyvault/deployment/secret/<name>.yml)."
  type = map(object({
    # Resource ID of the Key Vault (/subscriptions/.../providers/Microsoft.KeyVault/vaults/<name>).
    key_vault_id = string
    # Key Vault secret receiving the credential's secret.
    name = string
    # Optional Key Vault secret receiving the credential's username.
    username_name = optional(string)
    content_type  = optional(string)
    tags          = optional(map(string), {})
    # Added by the engine to every deployment config.
    config_file = optional(string)
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
