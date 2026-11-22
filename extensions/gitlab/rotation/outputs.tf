output "secret" {
  description = "id => { username = token name, secret = token }"
  value = {
    for k, v in var.configurations : k => {
      username = local.names[k]
      secret   = v.project != null ? gitlab_project_access_token.this[k].token : gitlab_group_access_token.this[k].token
    }
  }
  sensitive = true
}
