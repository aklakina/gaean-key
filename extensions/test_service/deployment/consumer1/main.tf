resource "terraform_data" "main" {
  for_each = var.configurations
  input = {
    username    = var.secrets[each.value.secret.service][each.value.secret.id].username
    secret      = var.secrets[each.value.secret.service][each.value.secret.id].secret
    id          = each.value.id
    description = each.value.description
  }
}