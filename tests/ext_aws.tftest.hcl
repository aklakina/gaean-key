# Unit test of extensions/aws/rotation against a mock AWS provider.

mock_provider "aws" {}

run "rotates_access_key_of_user" {
  command = apply

  module {
    source = "./extensions/aws/rotation"
  }

  variables {
    configurations = {
      ci-deployer = { user = "ci-deployer" }
    }
  }

  assert {
    condition     = aws_iam_access_key.this["ci-deployer"].user == "ci-deployer"
    error_message = "The access key must belong to the configured IAM user."
  }

  assert {
    condition     = output.secret["ci-deployer"].username == aws_iam_access_key.this["ci-deployer"].id
    error_message = "username must be the access key id."
  }

  assert {
    condition     = output.secret["ci-deployer"].secret == aws_iam_access_key.this["ci-deployer"].secret
    error_message = "secret must be the secret access key."
  }
}
