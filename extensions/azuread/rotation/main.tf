data "azuread_application" "this" {
  for_each = var.configurations

  client_id = each.value.client_id
}

# Creation time, fixed for the lifetime of this phase, so end_date stays stable across runs.
resource "time_static" "created" {
  for_each = var.configurations
}

resource "azuread_application_password" "this" {
  for_each = var.configurations

  application_id = data.azuread_application.this[each.key].id
  display_name   = coalesce(each.value.display_name, "gaean-key ${each.key} ${formatdate("YYYY-MM-DD", time_static.created[each.key].rfc3339)}")
  end_date       = timeadd(time_static.created[each.key].rfc3339, templatestring(each.value.expires_in, {}))
}
