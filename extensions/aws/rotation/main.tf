resource "aws_iam_access_key" "this" {
  for_each = var.configurations

  user = each.value.user
}
