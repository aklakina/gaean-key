# Creation time, fixed for the lifetime of this phase, so expires_at stays stable across runs.
resource "time_static" "created" {
  for_each = var.configurations
}

locals {
  # A phase exists for expires_in + rotation_window (it is created rotation_window before
  # consumers switch to it and destroyed rotation_window after they switch away), so the token
  # must stay valid that long; a lifetime of only expires_in would leave no overlap. Same minute
  # rounding and default window (20%) as the engine's rotation schedule.
  expiry_minutes = {
    for k, v in var.configurations : k => floor(provider::time::duration_parse(templatestring(v.expires_in, {})).minutes)
  }
  lifetime_minutes = {
    for k, v in var.configurations : k => local.expiry_minutes[k] + (
      v.rotation_window != null
      ? floor(provider::time::duration_parse(templatestring(v.rotation_window, {})).minutes)
      : floor(local.expiry_minutes[k] * 0.2)
    )
  }
  # GitLab expiry dates have day precision (the token expires at 00:00 UTC of expires_at): round
  # up to the next date so the token is valid for at least the full lifetime.
  expires_at = {
    for k, v in var.configurations :
    k => formatdate("YYYY-MM-DD", timeadd(time_static.created[k].rfc3339, "${local.lifetime_minutes[k] + 24 * 60}m"))
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
