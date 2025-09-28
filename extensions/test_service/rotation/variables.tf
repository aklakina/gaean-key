variable "configurations" {
  type = map(object({
    name_prefix     = optional(string, "tf-")
    password_length  = optional(number, 16)
  }))
}