// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  deployment_flat_configs = [
    {
      config = merge(local.service_defaults, yamldecode(file("${local.gaean_root}/configurations/test_service/deployment/consumer1/a/consume1.yml")), {
        config_file = "configurations/test_service/deployment/consumer1/a/consume1.yml"
      })
      config_name = "consume1"
      path_segments = [
        "consumer1",
        "a",
      ]
      service = "test_service"
    },
    {
      config = merge(local.service_defaults, yamldecode(file("${local.gaean_root}/configurations/test_service/deployment/consumer1/b/consume2.yml")), {
        config_file = "configurations/test_service/deployment/consumer1/b/consume2.yml"
      })
      config_name = "consume2"
      path_segments = [
        "consumer1",
        "b",
      ]
      service = "test_service"
    },
  ]
}
data "jinja_template" "configurations" {
  context {
    data = yamlencode({
      stage        = "deployment"
      flat_configs = local.deployment_flat_configs
    })
    type = "yaml"
  }
  source {
    directory = path.module
    template  = file("${local.gaean_root}/modules/config_processor.jinja2")
  }
}
locals {
  configurations = jsondecode(data.jinja_template.configurations.result)["test_service"]["consumer1"]
}
module "extension" {
  configurations = local.configurations
  depends_on = [
    terraform_data.mock_guard,
  ]
  secrets = local.secrets
  source  = "../../../../extensions/test_service/deployment"
}
