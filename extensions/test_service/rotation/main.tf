resource "random_string" "main" {
  for_each = var.configurations
  length   = 5
  special  = false
}

resource "random_password" "main" {
  for_each = var.configurations
  length   = each.value.password_length
  special  = true
}