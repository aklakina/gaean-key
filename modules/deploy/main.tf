module "test_service" {
  source = "../../extensions/test_service/deployment"
  for_each = var.configs.test_service

  configurations = each.value
  secrets = var.secrets
}
