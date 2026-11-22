data "azuread_application" "this" {
  for_each = var.configurations

  client_id = each.value.client_id
}

# Creation time, fixed for the lifetime of this phase, so end_date stays stable across runs.
resource "time_static" "created" {
  for_each = var.configurations
}

locals {
  # A phase exists for expires_in + rotation_window (it is created rotation_window before
  # consumers switch to it and destroyed rotation_window after they switch away), so the secret
  # must stay valid that long. A lifetime of only expires_in would make the previous secret expire
  # exactly when consumers switch away from it, leaving no overlap. Same minute rounding and
  # default window (20%) as the engine's rotation schedule.
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
}

resource "azuread_application_password" "this" {
  for_each = var.configurations

  application_id = data.azuread_application.this[each.key].id
  display_name   = coalesce(each.value.display_name, "gaean-key ${each.key} ${formatdate("YYYY-MM-DD", time_static.created[each.key].rfc3339)}")
  end_date       = timeadd(time_static.created[each.key].rfc3339, "${local.lifetime_minutes[each.key]}m")
}
