# One phase1/phase2 module pair per rotated service. Add a pair here (and an entry in
# outputs.tf) when wiring in a new rotation extension. Extensions that need a provider get
# the gated instance from providers.tf.

module "test_service_phase1" {
  for_each       = lookup(local.phase1, "test_service", {})
  source         = "../../extensions/test_service/rotation"
  configurations = { (each.key) : each.value }
}

module "test_service_phase2" {
  for_each       = lookup(local.phase2, "test_service", {})
  source         = "../../extensions/test_service/rotation"
  configurations = { (each.key) : each.value }
}

module "aws_phase1" {
  for_each       = lookup(local.phase1, "aws", {})
  source         = "../../extensions/aws/rotation"
  configurations = { (each.key) : each.value }
  providers = {
    aws = aws.rotation["default"]
  }
}

module "aws_phase2" {
  for_each       = lookup(local.phase2, "aws", {})
  source         = "../../extensions/aws/rotation"
  configurations = { (each.key) : each.value }
  providers = {
    aws = aws.rotation["default"]
  }
}

module "azuread_phase1" {
  for_each       = lookup(local.phase1, "azuread", {})
  source         = "../../extensions/azuread/rotation"
  configurations = { (each.key) : each.value }
  providers = {
    azuread = azuread.rotation["default"]
  }
}

module "azuread_phase2" {
  for_each       = lookup(local.phase2, "azuread", {})
  source         = "../../extensions/azuread/rotation"
  configurations = { (each.key) : each.value }
  providers = {
    azuread = azuread.rotation["default"]
  }
}

module "gitlab_phase1" {
  for_each       = lookup(local.phase1, "gitlab", {})
  source         = "../../extensions/gitlab/rotation"
  configurations = { (each.key) : each.value }
  providers = {
    gitlab = gitlab.rotation["default"]
  }
}

module "gitlab_phase2" {
  for_each       = lookup(local.phase2, "gitlab", {})
  source         = "../../extensions/gitlab/rotation"
  configurations = { (each.key) : each.value }
  providers = {
    gitlab = gitlab.rotation["default"]
  }
}
