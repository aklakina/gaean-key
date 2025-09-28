variable "configurations" {
  type = map(object({
    username = string
    secret   = string
  }))
}