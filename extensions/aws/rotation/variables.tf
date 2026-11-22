variable "configurations" {
  description = "Rotation configs keyed by id. Each rotates an access key of an existing IAM user."
  type = map(object({
    # Name of the IAM user. AWS allows at most 2 access keys per user and the dual-phase rotation
    # uses both slots during the rotation window, so the user must not have any other access keys.
    user = string
  }))
}
