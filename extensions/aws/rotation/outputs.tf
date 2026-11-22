output "secret" {
  description = "id => { username = access key id, secret = secret access key }"
  value = {
    for k, key in aws_iam_access_key.this : k => {
      username = key.id
      secret   = key.secret
    }
  }
  sensitive = true
}
