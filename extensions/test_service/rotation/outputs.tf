output "secret" {
  value = {for k, v in var.configurations : k => {
    username = "${v.name_prefix}${random_string.main[k].result}"
    secret   = random_password.main[k].result
  }}
}