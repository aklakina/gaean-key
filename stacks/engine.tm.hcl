# The Gaean Key engine: OpenTofu code generated into every stack written by scripts/sync_stacks.py.
#
# Every such stack sets `globals "gaean"`:
#   stage            get | rotation | deployment
#   service          service name (top-level folder of configurations/)
#   id               secret id (get/rotation) or deployment unit (first folder under deployment/)
#   extension        repo-relative path of the extension component the stack calls
#   config_var       name of the extension's configuration variable (configurations/configs/configuration)
#   output_name      name of the extension's secret output (secret/secrets), producers only
#   pass_secrets     whether the extension takes a `secrets` input
#   service_files    [configurations/<service>/service.yml] if it exists, else []
#   config_files     repo-relative paths of the YAML configs of the stack
#   deployment_files deployment only: [{path_segments, name, file}] relative to deployment/
#   secret_refs      input name => {service, id} of every referenced credential (one `input` block each)
#
# Run `terramate generate` after changing this file or the stacks.

generate_hcl "_gaean_terraform.tf" {
  condition = tm_can(global.gaean.stage)

  content {
    terraform {
      required_version = ">= 1.12.0"

      # A module has only one required_providers block, so extension hooks (gaean.tm.hcl) add the
      # providers they configure through the global gaean_required_providers instead of their own.
      # The root module must name the source of every provider it configures, or e.g.
      # `provider "gitlab"` would mean hashicorp/gitlab instead of the extension's gitlabhq/gitlab.
      tm_dynamic "required_providers" {
        condition = global.gaean.stage == "deployment" || tm_length(tm_try(global.gaean_required_providers, {})) > 0
        attributes = tm_merge(
          global.gaean.stage == "deployment" ? {
            jinja = {
              source  = "NikolaLohinski/jinja"
              version = ">= 2.4.3"
            }
          } : {},
          tm_try(global.gaean_required_providers, {}),
        )
      }
    }

    tm_dynamic "provider" {
      condition = global.gaean.stage == "deployment"
      labels    = ["jinja"]
      attributes = {
        trim_blocks      = true
        strict_undefined = true
      }
    }
  }
}

# Configuration loading: the YAML files stay the source of truth and are read by OpenTofu at plan
# time. service.yml is merged underneath every config as defaults (file values win).
generate_hcl "_gaean_config.tf" {
  condition = tm_can(global.gaean.stage)

  content {
    locals {
      gaean_root = "${path.module}/${terramate.stack.path.to_root}"

      service_defaults = merge({}, [
        for f in global.gaean.service_files : tm_hcl_expression("yamldecode(file(\"$${local.gaean_root}/${f}\"))")
      ]...)

      # Placeholder credentials consumers can reference (secret: {service: none, id: none})
      # before the real credential exists.
      placeholder_secrets = {
        none = {
          none = {
            username = "none"
            secret   = "none"
          }
        }
        TBD = {
          TBD = {
            username = "TBD"
            secret   = "TBD"
          }
        }
      }

      # Referenced credentials, from the producer stacks through outputs sharing.
      secret_refs   = global.gaean.secret_refs
      secret_values = { for name, _ in global.gaean.secret_refs : name => tm_hcl_expression("var.${name}") }

      # service => id => {username, secret}: only what this stack's configs reference.
      secrets = merge(local.placeholder_secrets, {
        for service in distinct([for ref in values(local.secret_refs) : ref.service]) : service => {
          for name, ref in local.secret_refs : ref.id => local.secret_values[name] if ref.service == service
        }
      })

      # A producer without state yields the mock credential (gaean_mock = true) when the run uses
      # --mock-on-fail. Fine for previewing a fresh setup, never for applying.
      uses_mock_credentials = anytrue([for v in values(local.secret_values) : nonsensitive(try(v.gaean_mock, false))])
    }

    check "mock_credentials" {
      assert {
        condition     = !local.uses_mock_credentials
        error_message = "Planned with mock credentials (--mock-on-fail): a producer stack this stack reads from has no state yet. This plan is a preview only; applying it will be refused. Apply the producer stacks first."
      }
    }

    # Refuses to apply with mock credentials, however the run was started (also a saved plan). Only
    # exists while mocks are used, and the extension modules depend on it, so nothing is deployed.
    # timestamp() is unknown while planning, so the condition is deferred and the preview plan
    # passes; during apply it is known and the condition fails.
    resource "terraform_data" "mock_guard" {
      count = local.uses_mock_credentials ? 1 : 0

      lifecycle {
        precondition {
          condition     = !local.uses_mock_credentials || timestamp() == ""
          error_message = "Refusing to apply with mock credentials (--mock-on-fail): apply the producer stacks first, then this stack without --mock-on-fail."
        }
      }
    }
  }
}

generate_hcl "_gaean_get.tf" {
  condition = tm_try(global.gaean.stage, null) == "get"

  content {
    locals {
      secret_id = global.gaean.id
      config = merge(
        local.service_defaults,
        tm_hcl_expression("yamldecode(file(\"$${local.gaean_root}/${global.gaean.config_files[0]}\"))"),
      )
    }

    tm_dynamic "module" {
      labels = ["extension"]
      attributes = tm_merge(
        {
          source                    = "${terramate.stack.path.to_root}/${global.gaean.extension}"
          (global.gaean.config_var) = tm_hcl_expression("{ (local.secret_id) = local.config }")
        },
        global.gaean.pass_secrets ? {
          secrets    = tm_hcl_expression("local.secrets")
          depends_on = tm_hcl_expression("[terraform_data.mock_guard]")
        } : {},
      )
    }

    locals {
      credential = tm_hcl_expression("module.extension.${global.gaean.output_name}[local.secret_id]")
    }
  }
}

# Dual-phase rotation of one credential: the schedule decides which phase modules exist and which
# one consumers get (see docs/secret_flow.md).
generate_hcl "_gaean_rotation.tf" {
  condition = tm_try(global.gaean.stage, null) == "rotation"

  content {
    locals {
      secret_id = global.gaean.id
      config = merge(
        local.service_defaults,
        tm_hcl_expression("yamldecode(file(\"$${local.gaean_root}/${global.gaean.config_files[0]}\"))"),
      )
    }

    module "schedule" {
      source = "${terramate.stack.path.to_root}/modules/rotation_schedule"

      expires_in      = local.config.expires_in
      rotation_window = try(local.config.rotation_window, null)
    }

    tm_dynamic "module" {
      for_each = ["phase1", "phase2"]
      iterator = phase
      labels   = [phase.value]
      attributes = tm_merge(
        {
          count                     = tm_hcl_expression("module.schedule.${phase.value}_active ? 1 : 0")
          source                    = "${terramate.stack.path.to_root}/${global.gaean.extension}"
          (global.gaean.config_var) = tm_hcl_expression("{ (local.secret_id) = local.config }")
        },
        global.gaean.pass_secrets ? {
          secrets    = tm_hcl_expression("local.secrets")
          depends_on = tm_hcl_expression("[terraform_data.mock_guard]")
        } : {},
      )
    }

    locals {
      active_phase = tm_hcl_expression("module.schedule.use_phase2 ? module.phase2 : module.phase1")
      credential   = tm_hcl_expression("local.active_phase[0].${global.gaean.output_name}[local.secret_id]")
    }

    output "schedule" {
      description = "Rotation schedule of the credential."
      value = {
        start_time    = module.schedule.start_time
        phase1_active = module.schedule.phase1_active
        phase2_active = module.schedule.phase2_active
        use_phase2    = module.schedule.use_phase2
      }
    }
  }
}

# One deployment unit (configurations/<service>/deployment/<unit>/**): the configs are nested by
# folder structure (modules/config_processor.jinja2) and passed to the extension's deployment
# component together with the credentials they reference.
generate_hcl "_gaean_deployment.tf" {
  condition = tm_try(global.gaean.stage, null) == "deployment"

  content {
    locals {
      deployment_flat_configs = [
        for f in global.gaean.deployment_files : {
          service       = global.gaean.service
          path_segments = f.path_segments
          config_name   = f.name
          config = tm_hcl_expression(<<-EOT
            merge(
              local.service_defaults,
              yamldecode(file("$${local.gaean_root}/${f.file}")),
              # repo-relative path of the file, e.g. for "managed by" notices on the deployed resources
              { config_file = "${f.file}" },
            )
          EOT
          )
        }
      ]
    }

    data "jinja_template" "configurations" {
      context {
        type = "yaml"
        data = yamlencode({
          stage        = "deployment"
          flat_configs = local.deployment_flat_configs
        })
      }
      source {
        template  = file("${local.gaean_root}/modules/config_processor.jinja2")
        directory = path.module
      }
    }

    locals {
      configurations = tm_hcl_expression("jsondecode(data.jinja_template.configurations.result)[\"${global.gaean.service}\"][\"${global.gaean.id}\"]")
    }

    tm_dynamic "module" {
      labels = ["extension"]
      attributes = {
        source                    = "${terramate.stack.path.to_root}/${global.gaean.extension}"
        (global.gaean.config_var) = tm_hcl_expression("local.configurations")
        secrets                   = tm_hcl_expression("local.secrets")
        depends_on                = tm_hcl_expression("[terraform_data.mock_guard]")
      }
    }
  }
}
