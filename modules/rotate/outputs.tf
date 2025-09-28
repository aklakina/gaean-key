output "credentials" {
  value = {
    test_service = merge([
      for phase, config in local.phases : {
        for k, v in local.phases[phase]["test_service"] : k => module.test_service[phase].secret[k] if !v.decommissioning
      } if contains(keys(config), "test_service") && length(config["test_service"]) > 0
    ]...)
  }
}