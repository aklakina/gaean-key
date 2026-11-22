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
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = ">= 17.0"
    }
  }
}
