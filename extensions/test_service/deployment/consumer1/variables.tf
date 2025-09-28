variable "configurations" {
  type = map(object({
    id = string
    description = optional(string, "Managed by Terraform")
    secret = object({
      service = string
      id      = string
    })
  }))
}

variable "secrets" {
  type = map(map(object({
    username = string
    secret   = string
  })))
}