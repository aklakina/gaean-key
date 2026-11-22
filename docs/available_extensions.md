# Available Extensions

| Service folder (`configurations/<service>/`) | Component | What it does |
|---|---|---|
| [`aws`](#aws-iam-access-keys) | Rotation | Rotates access keys of IAM users |
| [`azuread`](#entra-id-application-client-secrets) | Rotation | Rotates client secrets of Entra ID (Azure AD) app registrations |
| [`gitlab`](#gitlab-project-and-group-access-tokens) | Rotation | Rotates GitLab project and group access tokens |
| [`github`](#github-actions-secrets) | Deployment | Deploys credentials as GitHub Actions repository or environment secrets |
| [`azure_keyvault`](#azure-key-vault-secrets) | Store | Stores credentials as Azure Key Vault secrets |
| `test_service` | Get, Rotation, Deployment | Local-only sample extension used by the test suite |

Ready-to-adapt configurations for all of them are in [`examples/configurations/`](../examples/configurations); copy the ones you need into `configurations/`.

## Enabling a service and its provider

Every extension above (except `test_service`) needs a provider. The engine creates a provider instance for a service **only while `configurations/<service>/` contains a `.yml` file** (a config or a `service.yml`), so you only need credentials for the services you actually use.

- **Credentials** come from the provider's standard environment variables (listed per extension below), so nothing secret needs to be in the repository or in tfvars.
- **Non-secret settings** (region, GitHub owner, GitLab URL, tenant, subscription) can also be set with the optional root variable `provider_settings`, see [`versions.tf`](../versions.tf).
- **Retiring a service**: delete its configs and apply (this destroys the credentials), then delete its `service.yml`. If you delete the whole folder at once, the provider disappears before OpenTofu can destroy the credentials ("Provider instance not present"); restore `service.yml` and apply again.

All rotations follow the engine's dual-phase scheme: every config needs `expires_in` and may set `rotation_window` (default 20% of `expires_in`), see [Secret Flow](./secret_flow.md#rotate). Rotation only happens when OpenTofu runs, so run `tofu apply` on a schedule well under half the rotation window (e.g. a daily pipeline): a switch happens at the first run after its boundary, and that delay comes out of the overlap.

---

## AWS IAM access keys

`configurations/aws/rotation/<id>.yml`

```yaml
user: backup-agent   # existing IAM user
expires_in: "${90*24}h"
rotation_window: "${7*24}h"
```

| Field | Required | Description |
|---|---|---|
| `user` | yes | Name of the IAM user whose access key is rotated |

Provides `aws/<id>` with `username` = access key id, `secret` = secret access key.

- **Credentials**: `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE`, SSO, or any other source of the AWS provider; region from `AWS_REGION` or `provider_settings.aws.region`. Needs `iam:CreateAccessKey`, `iam:DeleteAccessKey`, `iam:ListAccessKeys` on the users.
- **Two-key limit**: AWS allows two access keys per user and both are in use during the rotation window, so the user must not have any other access keys.
- Access keys don't expire in AWS; `expires_in` only sets how long a key is used before it is replaced.

## Entra ID application client secrets

`configurations/azuread/rotation/<id>.yml`

```yaml
client_id: 11111111-1111-1111-1111-111111111111
expires_in: "${180*24}h"
rotation_window: "${14*24}h"
```

| Field | Required | Description |
|---|---|---|
| `client_id` | yes | Application (client) ID of the app registration |
| `display_name` | no | Name of the client secret; default `gaean-key <id> <creation date>` |

Provides `azuread/<id>` with `username` = client id, `secret` = client secret. The secret's `end_date` in Entra ID is its creation time + `expires_in` + `rotation_window` (the time its phase exists, so the old secret stays valid through the overlap), so an unrotated secret really stops working.

- **Credentials**: the azuread provider's standard sources (`ARM_CLIENT_ID`/`ARM_CLIENT_SECRET`/`ARM_TENANT_ID`, OIDC, managed identity, Azure CLI); tenant also via `provider_settings.azuread.tenant_id`. The identity must be allowed to manage credentials of the apps (e.g. owner of the app registrations, or `Application.ReadWrite.OwnedBy`).

## GitLab project and group access tokens

`configurations/gitlab/rotation/<id>.yml`

```yaml
project: my-group/my-project   # or: group: my-group
scopes: [read_repository]
access_level: reporter
expires_in: "${60*24}h"
rotation_window: "${7*24}h"
```

| Field | Required | Description |
|---|---|---|
| `project` / `group` | exactly one | ID or full path of the project or group |
| `scopes` | yes | Token scopes, e.g. `read_repository`, `read_registry`, `api` |
| `access_level` | no | `guest`, `reporter`, `developer` (default), `maintainer`, `owner` |
| `name` | no | Token name, default `gaean-key-<id>`; also the credential's `username` |
| `description` | no | Default `Managed by Gaean Key` |

Provides `gitlab/<id>` with `username` = token name, `secret` = token.

- **Credentials**: `GITLAB_TOKEN` (a token allowed to create access tokens on the projects/groups, e.g. a maintainer's or owner's); self-managed instances via `GITLAB_BASE_URL` or `provider_settings.gitlab.base_url`.
- The token's `expires_at` is the date of creation + `expires_in` + `rotation_window` (the time its phase exists), **rounded up** because GitLab expiry dates have day precision. The instance enforces a maximum lifetime (365 days by default), so keep `expires_in` + `rotation_window` + 1 day within it.

## GitHub Actions secrets

`configurations/github/deployment/actions_secret/<name>.yml`

```yaml
repository: my-mirror
secret_name: GITLAB_TOKEN
username_secret_name: GITLAB_USERNAME   # optional
environment: production                 # optional: environment secret instead of repository secret
secret:
  service: gitlab
  id: mirror-read
```

| Field | Required | Description |
|---|---|---|
| `repository` | yes | Repository name (owner from `GITHUB_OWNER` or `provider_settings.github.owner`) |
| `secret_name` | yes | Actions secret receiving the credential's secret |
| `username_secret_name` | no | Actions secret receiving the credential's username |
| `environment` | no | Create environment secrets in this environment instead of repository secrets |
| `secret` | yes | `service`/`id` of the credential to deploy |

- **Credentials**: `GITHUB_TOKEN` (or a GitHub App via the provider's `GITHUB_APP_*` variables) with permission to manage Actions secrets of the repositories; GitHub Enterprise Server via `GITHUB_BASE_URL` or `provider_settings.github.base_url`.
- A reference to a credential that no extension retrieves or rotates fails the plan.

## Azure Key Vault secrets

`configurations/azure_keyvault/deployment/secret/<name>.yml`

```yaml
key_vault_id: /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>
name: crm-sync-client-secret
username_name: crm-sync-client-id   # optional
content_type: client-secret         # optional
tags: { team: integrations }        # optional
secret:
  service: azuread
  id: crm-sync
```

| Field | Required | Description |
|---|---|---|
| `key_vault_id` | yes | Resource ID of the vault |
| `name` | yes | Key Vault secret receiving the credential's secret |
| `username_name` | no | Key Vault secret receiving the credential's username |
| `content_type` | no | Content type of the secret(s) |
| `tags` | no | Extra tags; `managed-by = gaean-key` and `config-file = <path of the config>` are always added |
| `secret` | yes | `service`/`id` of the credential to store |

- **Credentials**: the azurerm provider's standard sources (`ARM_*` variables, OIDC, managed identity, Azure CLI); subscription from `ARM_SUBSCRIPTION_ID` or `provider_settings.azurerm.subscription_id`. The identity needs to set secrets in the vault (e.g. the *Key Vault Secrets Officer* role).
- A reference to a credential that no extension retrieves or rotates fails the plan.

---

## Writing your own

See [Extension Development](./extension_development.md). The extensions above are small (one resource type each) and make good templates: `aws` for a rotation without expiry, `azuread`/`gitlab` for rotations with a provider-side expiry, `github`/`azure_keyvault` for consumers.
