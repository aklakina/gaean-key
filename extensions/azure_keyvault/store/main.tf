locals {
  # Credential ids per service; plan-time known, used to fail early on dangling references.
  available = nonsensitive({ for service, creds in var.secrets : service => keys(creds) })

  # One entry per Key Vault secret: the credential's secret and, optionally, its username.
  entries = merge(
    {
      for k, v in var.configurations : "${k}/secret" => {
        config = k
        cfg    = v
        name   = v.name
        field  = "secret"
      }
    },
    {
      for k, v in var.configurations : "${k}/username" => {
        config = k
        cfg    = v
        name   = v.username_name
        field  = "username"
      } if v.username_name != null
    }
  )
}

resource "azurerm_key_vault_secret" "this" {
  for_each = local.entries

  key_vault_id = each.value.cfg.key_vault_id
  name         = each.value.name
  value        = var.secrets[each.value.cfg.secret.service][each.value.cfg.secret.id][each.value.field]
  content_type = each.value.cfg.content_type
  tags = merge(
    each.value.cfg.tags,
    { "managed-by" = "gaean-key" },
    each.value.cfg.config_file != null ? { "config-file" = each.value.cfg.config_file } : {}
  )

  lifecycle {
    precondition {
      condition     = contains(lookup(local.available, each.value.cfg.secret.service, []), each.value.cfg.secret.id)
      error_message = "azure_keyvault/secret/${each.value.config}: no credential '${each.value.cfg.secret.service}/${each.value.cfg.secret.id}' is retrieved or rotated."
    }
  }
}
