module "test_service" {
  source = "../../extensions/test_service/rotation"

  for_each       = { for k, v in local.phases : k => v if contains(keys(v), "test_service") && length(v["test_service"]) > 0 }
  configurations = local.phases[each.key]["test_service"]
}
