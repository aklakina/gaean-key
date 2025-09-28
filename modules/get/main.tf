module "test_service" {
  source = "../../extensions/test_service/get"
  configurations = var.configs.test_service
}