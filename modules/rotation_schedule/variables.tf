variable "expires_in" {
  description = "How long a credential is valid, as a duration parsable by provider::time::duration_parse (templates such as \"$${30*24}h\" are allowed)."
  type        = string

  validation {
    condition     = can(provider::time::duration_parse(templatestring(var.expires_in, {})))
    error_message = "expires_in must be a duration parsable by provider::time::duration_parse (e.g. \"720h\" or \"$${30*24}h\")."
  }
}

variable "rotation_window" {
  description = "Overlap during which the old and the new credential are both valid. Defaults to 20% of expires_in."
  type        = string
  default     = null

  validation {
    condition = var.rotation_window == null || try(
      provider::time::duration_parse(templatestring(var.expires_in, {})).seconds >
      provider::time::duration_parse(templatestring(var.rotation_window, {})).seconds,
      false
    )
    error_message = "rotation_window must be a duration parsable by provider::time::duration_parse and shorter than expires_in."
  }
}
