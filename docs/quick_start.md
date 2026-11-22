# Quick Start

## Prerequisites

- [OpenTofu](https://opentofu.org/) 1.13+ (the engine uses the OpenTofu-only `convert()` function)
- Credentials for the services you use (see below)

## 1. Pick the configurations

Copy the example configurations you need from [`examples/configurations/`](../examples/configurations) into `configurations/` and adapt them, or write your own (reference: [Available Extensions](./available_extensions.md)). Remove the `test_service` sample configurations once you don't need them anymore.

```bash
cp -r examples/configurations/gitlab examples/configurations/github configurations/
```

## 2. Provide provider credentials

A provider is only configured for services that have a folder with a `.yml` file under `configurations/`. Give each of those its credentials through the provider's standard environment variables, for example:

```bash
export GITLAB_TOKEN=...         # gitlab rotation
export GITHUB_TOKEN=...         # github deployment
export GITHUB_OWNER=my-org
```

In CI, prefer federation for the clouds themselves (e.g. `ARM_USE_OIDC=true` for Azure, an assumed role for AWS) so the rotation pipeline holds no long-lived secret of its own.

Optional non-secret settings (AWS region/profile, GitHub owner/URL, GitLab URL, tenant, subscription) can also go in a tfvars file, see the `provider_settings` variable in [`versions.tf`](../versions.tf):

```hcl
# settings.tfvars
provider_settings = {
  github = { owner = "my-org" }
  gitlab = { base_url = "https://gitlab.example.com/api/v4" }
}
```

## 3. Protect the state

Rotated credentials are stored in the OpenTofu state and plan. Configure a remote backend only the rotation pipeline can read, and enable [state and plan encryption](https://opentofu.org/docs/language/state/encryption/) in `versions.tf`.

## 4. Run from the repository root

```bash
tofu init [-upgrade]
tofu plan  [-var-file ./settings.tfvars]
tofu apply [-var-file ./settings.tfvars]
```

Then run `tofu apply` on a schedule that is much shorter than the rotation windows (e.g. daily): rotation only happens when OpenTofu runs.
