# Provider configuration of every stack running this component (imported by scripts/sync_stacks.py).
# Credentials come from the provider's environment variables (GITLAB_TOKEN); optional non-secret
# settings from the Terramate global provider_settings.gitlab (see docs/stacks.md#provider-configuration).

globals {
  # merged into the stack's required_providers by stacks/engine.tm.hcl
  gaean_required_providers = {
    gitlab = {
      source = "gitlabhq/gitlab"
    }
  }
}

generate_hcl "_gaean_providers.tf" {
  content {
    provider "gitlab" {
      base_url = tm_try(global.provider_settings.gitlab.base_url, null)
    }
  }
}
