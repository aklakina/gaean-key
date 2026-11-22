output "secret" {
  description = "id => { username = client id, secret = client secret }"
  value = {
    for k, cfg in var.configurations : k => {
      username = cfg.client_id
      secret   = azuread_application_password.this[k].value
    }
  }
  sensitive = true
}
