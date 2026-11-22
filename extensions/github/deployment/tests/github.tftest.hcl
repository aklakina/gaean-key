# Unit test of this extension component against a mock GitHub provider.

mock_provider "github" {}

variables {
  secrets = {
    gitlab = {
      ci-read = { username = "gaean-key-ci-read", secret = "token-value" }
    }
  }
}

run "deploys_repository_and_environment_secrets" {
  command = apply

  variables {
    configurations = {
      repo-token = {
        repository           = "my-repo"
        secret_name          = "GITLAB_TOKEN"
        username_secret_name = "GITLAB_USER"
        secret               = { service = "gitlab", id = "ci-read" }
      }
      prod-token = {
        repository  = "my-repo"
        environment = "production"
        secret_name = "GITLAB_TOKEN"
        secret      = { service = "gitlab", id = "ci-read" }
      }
    }
  }

  assert {
    condition     = length(github_actions_secret.this) == 2 && length(github_actions_environment_secret.this) == 1
    error_message = "Expected 2 repository secrets (secret + username) and 1 environment secret."
  }

  assert {
    condition     = github_actions_secret.this["repo-token/secret"].value == "token-value"
    error_message = "secret_name must receive the credential's secret."
  }

  assert {
    condition     = github_actions_secret.this["repo-token/username"].value == "gaean-key-ci-read"
    error_message = "username_secret_name must receive the credential's username."
  }

  assert {
    condition     = github_actions_environment_secret.this["prod-token/secret"].environment == "production"
    error_message = "Configs with an environment must create environment secrets."
  }
}

run "rejects_unknown_credential" {
  command = plan

  variables {
    configurations = {
      dangling = {
        repository  = "my-repo"
        secret_name = "MISSING"
        secret      = { service = "gitlab", id = "does-not-exist" }
      }
    }
  }

  expect_failures = [github_actions_secret.this]
}
