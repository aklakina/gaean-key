locals {
  # Credential ids per service; plan-time known, used to fail early on dangling references.
  available = nonsensitive({ for service, creds in var.secrets : service => keys(creds) })

  # One entry per Actions secret: the credential's secret and, optionally, its username.
  entries = merge(
    {
      for k, v in var.configurations : "${k}/secret" => {
        config      = k
        repository  = v.repository
        environment = v.environment
        name        = v.secret_name
        field       = "secret"
        ref         = v.secret
      }
    },
    {
      for k, v in var.configurations : "${k}/username" => {
        config      = k
        repository  = v.repository
        environment = v.environment
        name        = v.username_secret_name
        field       = "username"
        ref         = v.secret
      } if v.username_secret_name != null
    }
  )
}

resource "github_actions_secret" "this" {
  for_each = { for k, v in local.entries : k => v if v.environment == null }

  repository  = each.value.repository
  secret_name = each.value.name
  value       = var.secrets[each.value.ref.service][each.value.ref.id][each.value.field]

  lifecycle {
    precondition {
      condition     = contains(lookup(local.available, each.value.ref.service, []), each.value.ref.id)
      error_message = "github/actions_secret/${each.value.config}: no credential '${each.value.ref.service}/${each.value.ref.id}' is retrieved or rotated."
    }
  }
}

resource "github_actions_environment_secret" "this" {
  for_each = { for k, v in local.entries : k => v if v.environment != null }

  repository  = each.value.repository
  environment = each.value.environment
  secret_name = each.value.name
  value       = var.secrets[each.value.ref.service][each.value.ref.id][each.value.field]

  lifecycle {
    precondition {
      condition     = contains(lookup(local.available, each.value.ref.service, []), each.value.ref.id)
      error_message = "github/actions_secret/${each.value.config}: no credential '${each.value.ref.service}/${each.value.ref.id}' is retrieved or rotated."
    }
  }
}
