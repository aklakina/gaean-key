# One phase1/phase2 module pair per rotated service. Add a pair here (and an entry in
# outputs.tf) when wiring in a new rotation extension.

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
