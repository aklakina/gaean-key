# Provider configuration of every stack running this component (imported by scripts/sync_stacks.py).
# Credentials come from the provider's environment variables; optional non-secret settings from the
# Terramate global provider_settings.aws (see docs/stacks.md#provider-configuration).

globals {
  # merged into the stack's required_providers by stacks/engine.tm.hcl
  gaean_required_providers = {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

generate_hcl "_gaean_providers.tf" {
  content {
    provider "aws" {
      region  = tm_try(global.provider_settings.aws.region, null)
      profile = tm_try(global.provider_settings.aws.profile, null)
    }
  }
}
