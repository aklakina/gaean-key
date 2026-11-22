variable "secrets" {
  sensitive = true
}
variable "configs" {}

variable "provider_settings" {
  description = "Non-secret provider settings, see the root variable of the same name."
}
