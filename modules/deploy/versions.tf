terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.13.0, < 7.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}
