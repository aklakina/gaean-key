# Gaean Key

[![OpenTofu Tests](https://github.com/aklakina/gaean-key/actions/workflows/terraform-tests.yml/badge.svg)](https://github.com/aklakina/gaean-key/actions/workflows/terraform-tests.yml)

**Rotate the credentials you can't federate.** Gaean Key is an OpenTofu project that mints, rotates and distributes long-lived credentials (API tokens, client secrets, access keys) from YAML files in Git, with a zero-downtime overlap between the old and the new credential.

```yaml
# configurations/gitlab/rotation/mirror-read.yml: a GitLab token, replaced every 60 days
project: my-group/my-project
scopes: [read_repository]
expires_in: "${60*24}h"
rotation_window: "${7*24}h"
```

```yaml
# configurations/github/deployment/actions_secret/mirror-read.yml: ...kept up to date in GitHub Actions
repository: my-mirror
secret_name: GITLAB_TOKEN
secret: { service: gitlab, id: mirror-read }
```

A scheduled `tofu apply` does the rest: it creates the next token before the current one expires, switches every consumer over, and deletes the old token only after the overlap window. Changes are reviewed as pull requests, and `tofu plan` shows exactly which credentials and consumers a run will touch.

## When to use Gaean Key (and when not to)

**Use workload identity federation wherever you can.** If the consumer can get a short-lived token from its own identity provider and the target trusts it (GitHub Actions / GitLab CI / Azure Pipelines to AWS, Azure or GCP, Kubernetes workload identity, SPIFFE), there is no secret to leak or rotate. That is strictly better than any rotation, including this one.

Gaean Key is for the long tail that federation doesn't reach:

- **Targets without federation**: self-hosted servers (GitLab, Artifactory, Azure DevOps Server, password managers), SaaS APIs that only issue tokens or API keys, databases, SMTP and licence servers.
- **Consumers that aren't workloads with an identity**: config files (`.npmrc`, `NuGet.Config`, `.terraformrc`), appliances and vendor tools that take a static key, scripts on developer machines, partner teams.
- **One credential, many consumers**: a token that has to be in three CI systems and a vault, all updated together.

It is **not** a fit when you need per-request, minutes-long credentials (use dynamic secrets, below), or when every consumer can already federate.

### Alternatives

| | Removes long-lived secrets | Rotates the source credential | Distributes to consumers | Runs as | Scope |
|---|---|---|---|---|---|
| **Workload identity federation (OIDC)** | ✅ | n/a | n/a | built into clouds/CI | workloads with an identity, targets that trust it |
| **HashiCorp Vault / OpenBao dynamic secrets** | ✅ short-lived leases | ✅ | consumers fetch from Vault (agent, SDK, CSI) | a Vault cluster you operate | engines Vault supports; consumers must integrate with Vault |
| **Cloud secret-manager rotation** (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager) | ❌ | ✅ for a few managed services, otherwise you write the rotation function | consumers fetch from that cloud's store | the cloud | one cloud |
| **External Secrets Operator** | ❌ | ❌ (generators for a few types) | ✅ into Kubernetes | operator in the cluster | Kubernetes consumers |
| **CI/CD secret stores** (GitHub, GitLab, Azure DevOps variables) | ❌ | ❌ | that CI system only | the CI system | one tool |
| **Cron scripts** | ❌ | ✅ whatever you write | whatever you write | wherever they run | ad hoc |
| **Gaean Key** | ❌ | ✅ via extensions | ✅ via extensions, many targets per credential | `tofu apply` in a scheduled pipeline, no server | any provider OpenTofu has |

They combine well: run Gaean Key in a pipeline that authenticates to the clouds with federation, and use it to store rotated credentials in Vault or a cloud secret manager for consumers that already read from there.

### Trade-offs to know about

- **Secrets pass through OpenTofu state.** Rotated values end up in the state (and plan) files, like with any OpenTofu-managed credential. Use OpenTofu's [client-side state and plan encryption](https://opentofu.org/docs/language/state/encryption/) and a backend only the rotation pipeline can read.
- **Rotation happens when OpenTofu runs.** Schedule `tofu apply` well within the rotation window (for example daily); a missed run is caught up by the next one as long as it falls inside the window.
- **Lifetimes are days to months, not minutes.** That is the point (long-lived credentials for consumers that need them), but it is not a substitute for dynamic secrets.
- **The pipeline is privileged.** It can mint credentials, so protect it like any other deployment pipeline.

## How rotation works

Every rotated credential runs as two alternating "phases" with expiry `E` (`expires_in`) and overlap `W` (`rotation_window`, default 20% of `E`):

```
           0                E-W        E                 2E-W       2E
key A      ├──── in use ─────┼── old ───┤
key B                        ├───────────── in use ────────┼── old ───┤
key A'                                                     ├──── in use ───►
```

Consumers always get the newest key; the previous one stays valid for `W`, so anything that still holds it (a running job, a cached config) keeps working until it picks up the new one. See [Secret Flow](./docs/secret_flow.md#rotate).

## Extensions

| Service | Component | |
|---|---|---|
| `aws` | Rotation | IAM user access keys |
| `azuread` | Rotation | Entra ID app registration client secrets |
| `gitlab` | Rotation | GitLab project and group access tokens |
| `github` | Deployment | GitHub Actions repository and environment secrets |
| `azure_keyvault` | Store | Azure Key Vault secrets |

A provider is only configured for the services you have configurations for, so you only need credentials for what you use. Details and examples: [Available Extensions](./docs/available_extensions.md) and [`examples/configurations/`](./examples/configurations). New services are small modules following the [extension contract](./docs/extension_development.md).

## Documentation

1. [Quick Start](./docs/quick_start.md)
2. [High Level Overview](./docs/high_level_overview.md)
3. [Architecture Overview](./docs/architecture_overview.md)
4. [Secret Flow](./docs/secret_flow.md)
5. [Extension Development](./docs/extension_development.md)
6. [Available Extensions](./docs/available_extensions.md)
7. [Troubleshooting](./docs/troubleshooting.md)

## License

Licensed under the MIT License
