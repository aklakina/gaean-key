# The set of services/secret ids below is derived from config keys only, so it is known at
# plan time. Only the leaf values (username/secret) depend on resources and may be
# known-after-apply. convert() gives those unknown leaves a concrete type, and building
# each map with a for expression (instead of merge(...) over whole module outputs, which
# turns the entire result unknown as soon as one argument is unknown) keeps the structure
# known. This lets consumers resolve which resources a rotation cascades into at plan time.
output "credentials" {
  description = "The rotated credentials: service => id => {username, secret}, taken from the active phase."
  value = {
    test_service = {
      for key, value in local.all_configs : local.secret_ids[key] => convert(
        local.use_phase2[key]
        ? module.test_service_phase2[split("/", key)[1]].secret[local.secret_ids[key]]
        : module.test_service_phase1[split("/", key)[1]].secret[local.secret_ids[key]],
        object({ username = string, secret = string })
      )
      if split("/", key)[0] == "test_service"
    }
    aws = {
      for key, value in local.all_configs : local.secret_ids[key] => convert(
        local.use_phase2[key]
        ? module.aws_phase2[split("/", key)[1]].secret[local.secret_ids[key]]
        : module.aws_phase1[split("/", key)[1]].secret[local.secret_ids[key]],
        object({ username = string, secret = string })
      )
      if split("/", key)[0] == "aws"
    }
    azuread = {
      for key, value in local.all_configs : local.secret_ids[key] => convert(
        local.use_phase2[key]
        ? module.azuread_phase2[split("/", key)[1]].secret[local.secret_ids[key]]
        : module.azuread_phase1[split("/", key)[1]].secret[local.secret_ids[key]],
        object({ username = string, secret = string })
      )
      if split("/", key)[0] == "azuread"
    }
    gitlab = {
      for key, value in local.all_configs : local.secret_ids[key] => convert(
        local.use_phase2[key]
        ? module.gitlab_phase2[split("/", key)[1]].secret[local.secret_ids[key]]
        : module.gitlab_phase1[split("/", key)[1]].secret[local.secret_ids[key]],
        object({ username = string, secret = string })
      )
      if split("/", key)[0] == "gitlab"
    }
  }
  sensitive = true
}
