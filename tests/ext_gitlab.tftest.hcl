# Unit test of extensions/gitlab/rotation against a mock GitLab provider.

mock_provider "gitlab" {}

run "creates_project_and_group_tokens" {
  command = apply

  module {
    source = "./extensions/gitlab/rotation"
  }

  variables {
    configurations = {
      ci-read = {
        project    = "my-group/my-project"
        scopes     = ["read_repository"]
        expires_in = "720h"
      }
      registry = {
        group        = "my-group"
        name         = "registry-pull"
        scopes       = ["read_registry"]
        access_level = "reporter"
        expires_in   = "720h"
      }
    }
  }

  assert {
    condition     = length(gitlab_project_access_token.this) == 1 && length(gitlab_group_access_token.this) == 1
    error_message = "Project configs must create project tokens and group configs group tokens."
  }

  assert {
    # 720h + the default rotation window (20% = 144h) = 864h, rounded up to the next date (+24h,
    # then truncated): the token must stay valid as long as its phase exists.
    condition     = gitlab_project_access_token.this["ci-read"].expires_at == formatdate("YYYY-MM-DD", timeadd(time_static.created["ci-read"].rfc3339, "888h"))
    error_message = "expires_at must be the date of creation time + expires_in + default rotation window, rounded up."
  }

  assert {
    condition     = output.secret["ci-read"].username == "gaean-key-ci-read" && output.secret["registry"].username == "registry-pull"
    error_message = "username must be the token name (default gaean-key-<id>)."
  }

  assert {
    condition     = output.secret["registry"].secret == gitlab_group_access_token.this["registry"].token
    error_message = "secret must be the token of the matching resource."
  }
}

run "rejects_project_and_group_together" {
  command = plan

  module {
    source = "./extensions/gitlab/rotation"
  }

  variables {
    configurations = {
      both = {
        project    = "my-group/my-project"
        group      = "my-group"
        scopes     = ["read_repository"]
        expires_in = "720h"
      }
    }
  }

  expect_failures = [var.configurations]
}

run "expiry_covers_the_whole_phase_even_with_short_windows" {
  command = apply

  module {
    source = "./extensions/gitlab/rotation"
  }

  variables {
    configurations = {
      short = {
        project         = "my-group/my-project"
        scopes          = ["read_repository"]
        expires_in      = "720h"
        rotation_window = "12h"
      }
    }
  }

  assert {
    # the token expires at 00:00 UTC of expires_at, which must not be before creation + 732h
    condition     = timecmp("${gitlab_project_access_token.this["short"].expires_at}T00:00:00Z", timeadd(time_static.created["short"].rfc3339, "732h")) >= 0
    error_message = "With day precision the token must still be valid for expires_in + rotation_window."
  }

  assert {
    condition     = timecmp("${gitlab_project_access_token.this["short"].expires_at}T00:00:00Z", timeadd(time_static.created["short"].rfc3339, "756h")) <= 0
    error_message = "expires_at must be rounded up by at most one day."
  }
}
