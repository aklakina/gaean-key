output "secret" {
  value = {
    for k, v in var.configurations : k => {
      username = terraform_data.main[k].input["username"]
      secret   = terraform_data.main[k].input["secret"]
    }
  }
}