# Fix circular dependency in rotation resource lifecycle

- Status: accepted
- Date: 2026-03-03
- Tags: terraform, lifecycle, circular-dependency, rotation

Technical Story: When a rotation window activates (i.e., `time_rotating.cycle_timer` expires and triggers resource replacement), Terraform reports a cycle error involving `module.rotation`, `module.deployment`, and `local.merged_credentials`. The cycle prevents any plan or apply from succeeding once a credential's rotation timer fires.

## Context and Problem Statement

The rotation module uses `time_rotating` and `terraform_data` resources to drive the two-phase rotation scheme. When a timer expires, Terraform attempts to replace these resources using the default **destroy-before-create** ordering. This creates a circular dependency in the Terraform resource graph because:

1. **`local.start_times`** (in `modules/rotate/locals.tf`) references ALL `terraform_data.deterministic_time` instances via a `for` expression. Terraform's static dependency analysis conservatively treats this as a dependency on every instance, including ones being destroyed/replaced.

2. **`output "credentials"`** (in `modules/rotate/outputs.tf`) uses a conditional expression that references BOTH `phase1` and `phase2` module outputs for every config key, creating graph edges to all phase modules regardless of which branch is actually taken.

3. **Monolithic secrets passing**: The full aggregated `local.merged_credentials` map is passed as `var.secrets` to every deployment module, making every deployment resource transitively depend on every rotation resource.

When Terraform attempts a destroy-before-create replacement of `deterministic_time`:
- The **destroy node** for the old instance requires all dependents (deployment resources) to settle first (reverse dependency edge).
- But dependents need the **new** rotation credentials from the new phase modules.
- New phase modules need new phases → new `start_times` → **new** `deterministic_time`.
- New `deterministic_time` cannot be created until the old one is destroyed.
- This forms the cycle: `destroy(old) ← dependents settled ← new output ← new phases ← new start_times ← new deterministic_time ← old destroyed ← CYCLE`.

The shape of the error cycle reported by Terraform (service and resource names shortened):
```
module.rotation.terraform_data.deterministic_time (destroy)
  → module.rotation.time_rotating.cycle_timer (destroy)
  → module.rotation.module.<service_a>_phase1.output.secret (expand)
  → module.rotation.module.<service_b>_phase2.output.secret (expand)
  → module.rotation.output.credentials (expand)
  → local.merged_credentials (expand)
  → module.deployment.var.secrets (expand)
  → module.deployment.module.<consumer>.var.secrets (expand)
  → module.deployment.module.<consumer>.<resource> (expand)
  → ↻ back to deterministic_time (destroy)
```

## Decision Drivers

- **Availability**: Rotation must not block the entire Terraform run when a timer fires.
- **Minimal blast radius**: The fix should be scoped to the rotation module only, avoiding refactors of the deployment or output structures.
- **Correctness**: The two-phase rotation logic and time-window calculations must remain unchanged.
- **Simplicity**: Prefer a Terraform-native lifecycle configuration over architectural restructuring.

## Considered Options

- **Option 1**: Add `create_before_destroy = true` to the `time_rotating` and `terraform_data` resources.
- **Option 2**: Decouple the rotation output by splitting `output "credentials"` into per-service outputs and removing cross-service graph edges.
- **Option 3**: Break the monolithic `var.secrets` passing in `module.deployment` by only passing the specific secrets each deployment module needs.

## Decision Outcome

Chosen option: **"Option 1 — Add `create_before_destroy = true`"**, because it directly eliminates the cycle with a small change to `modules/rotate/main.tf`, requires no restructuring of modules or outputs, and preserves all existing rotation logic.

By switching to create-before-destroy:
1. **New** timer/deterministic_time instances are created first → provide new time values immediately.
2. Dependents update using new values (start_times → phases → module outputs → deployment).
3. **Old** instances are destroyed last, after all dependents have settled → no reverse dependency deadlock.

### Changes Made

In `modules/rotate/main.tf`:

```hcl
resource "time_rotating" "cycle_timer" {
  for_each         = local.all_configs
  rotation_minutes = floor(2 * local.expiry_minutes[each.key])

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "deterministic_time" {
  for_each = local.all_configs

  input = {
    time = plantimestamp()
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [input]
    replace_triggered_by  = [time_rotating.cycle_timer[each.key]]
  }
}
```

### Positive Consequences

- Eliminates the circular dependency error when rotation windows activate.
- No changes required to module interfaces, outputs, or deployment modules.
- The two-phase rotation scheme and time-window calculations remain completely intact.
- Terraform plans and applies proceed normally during active rotation windows.

### Negative Consequences

- During replacement, both old and new resource instances exist briefly at the same time. For `terraform_data` and `time_rotating` this is harmless (no external side-effects), but this pattern should be evaluated carefully if applied to resources with real infrastructure state.

## Pros and Cons of the Options

### Option 1 — `create_before_destroy = true`

- Good, because it is a minimal change confined to `modules/rotate/main.tf`.
- Good, because it directly addresses the root cause (destroy-ordering deadlock).
- Good, because `terraform_data` and `time_rotating` are stateless metadata resources with no external side-effects from brief coexistence.
- Bad, because it does not address the deeper architectural coupling (monolithic outputs and secrets passing) that amplifies the cycle.

### Option 2 — Split rotation output per service

Refactor `output "credentials"` into separate per-service outputs, and only wire each deployment module to the specific output it needs.

- Good, because it reduces the blast radius of graph edges (each deployment only depends on its own rotation service).
- Good, because it would make the Terraform graph sparser and plans faster.
- Bad, because it requires changes to `modules/rotate/outputs.tf`, the root `main.tf`, `local.merged_credentials`, and every deployment module's variable interface.
- Bad, because it is a much larger refactor with higher risk of regression.

### Option 3 — Selective secrets passing in deployment

Instead of passing the entire `var.secrets` map to each deployment module, pass only the specific secret each resource needs.

- Good, because it minimizes transitive dependencies from deployment resources to unrelated rotation resources.
- Good, because it aligns with the principle of least privilege for data access.
- Bad, because deployment configs reference secrets dynamically via their `secret.service` and `secret.id` fields, making static wiring difficult without restructuring the config loader.
- Bad, because it requires changes across all deployment extensions.
