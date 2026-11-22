terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13.1"
    }
    jinja = {
      source  = "NikolaLohinski/jinja"
      version = ">=2.4.3"
    }
  }
  required_version = ">= 1.13.0"
}

variable "provider_settings" {
  description = <<-EOT
    Optional non-secret settings of the extension providers. Credentials (and anything not listed
    here) come from each provider's standard environment variables, e.g. AWS_*, ARM_*,
    GITHUB_TOKEN, GITLAB_TOKEN. A provider is only configured while its service has a folder with
    a .yml file under configurations/, so you only need settings for the services you use.
  EOT
  type = object({
    aws = optional(object({
      region  = optional(string)
      profile = optional(string)
    }), {})
    azuread = optional(object({
      tenant_id = optional(string)
    }), {})
    gitlab = optional(object({
      base_url = optional(string)
    }), {})
    github = optional(object({
      owner    = optional(string)
      base_url = optional(string)
    }), {})
    azurerm = optional(object({
      subscription_id = optional(string)
      tenant_id       = optional(string)
    }), {})
  })
  default = {}
}

provider "time" {}

provider "jinja" {
  trim_blocks      = true
  strict_undefined = true
}
