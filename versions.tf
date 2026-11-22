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

provider "time" {}

provider "jinja" {
  trim_blocks      = true
  strict_undefined = true
}
