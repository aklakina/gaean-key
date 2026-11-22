# Creation time, fixed for the lifetime of this phase, so expires_at stays stable across runs.
resource "time_static" "created" {
  for_each = var.configurations
}

locals {
  expires_at = {
    for k, v in var.configurations :
    k => formatdate("YYYY-MM-DD", timeadd(time_static.created[k].rfc3339, templatestring(v.expires_in, {})))
  }
  names = { for k, v in var.configurations : k => coalesce(v.name, "gaean-key-${k}") }
}

resource "gitlab_project_access_token" "this" {
  for_each = { for k, v in var.configurations : k => v if v.project != null }

  project      = each.value.project
  name         = local.names[each.key]
  description  = each.value.description
  scopes       = each.value.scopes
  access_level = each.value.access_level
  expires_at   = local.expires_at[each.key]
}

resource "gitlab_group_access_token" "this" {
  for_each = { for k, v in var.configurations : k => v if v.group != null }

  group        = each.value.group
  name         = local.names[each.key]
  description  = each.value.description
  scopes       = each.value.scopes
  access_level = each.value.access_level
  expires_at   = local.expires_at[each.key]
}
