output "credentials" {
  value = {
    test_service = module.test_service.secret
  }
}