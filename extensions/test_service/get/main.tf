resource "terraform_data" "main" {
  for_each = var.configurations
  input = {
    username = each.value.username
    secret   = each.value.secret
  }
}