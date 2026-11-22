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
}
