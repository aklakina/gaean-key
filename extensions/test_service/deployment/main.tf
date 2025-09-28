module "consumer1" {
  for_each       = var.configurations
  source         = "./consumer1"
  configurations = each.value
  secrets        = var.secrets
}