module "test_service" {
  source         = "../../extensions/test_service/get"
  configurations = try(var.configs.test_service, {})
}
