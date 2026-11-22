# Provider configuration of every stack running this component (imported by scripts/sync_stacks.py).
# Credentials come from the provider's environment variables (GITHUB_TOKEN, GITHUB_APP_*); optional
# non-secret settings from the Terramate global provider_settings.github (see docs/stacks.md#provider-configuration).

globals {
  # merged into the stack's required_providers by stacks/engine.tm.hcl
  gaean_required_providers = {
    github = {
      source = "integrations/github"
    }
  }
}

generate_hcl "_gaean_providers.tf" {
  content {
    provider "github" {
      owner    = tm_try(global.provider_settings.github.owner, null)
      base_url = tm_try(global.provider_settings.github.base_url, null)
    }
  }
}
