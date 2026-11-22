# Secret Flow

The secret flow follows this pattern:

1. `scripts/sync_stacks.py` reads the `configurations/` directory and writes one Terramate stack per credential (get, rotation) and per deployment unit. A `service`/`id` may not be both retrieved and rotated, and every referenced credential must have a producer (Engine)
2. Inside each stack the generated code loads its configuration files, merged with the optional `service.yml` defaults (Engine)
3. Secrets are retrieved from credential management systems, one stack per credential (Get component)
4. Secrets are rotated using service-specific rotation logic with a dual-phase mechanism, one stack per credential (Rotation component). A rotation whose extension takes `secrets` receives the credentials its configuration references, so a rotated credential can depend on another one
5. Every producer stack exports its active credential; every consumer stack imports exactly the credentials its configurations reference (Terramate outputs sharing) and runs after their producers (Engine)
6. Secrets are deployed to target systems as configured (Deployment component)

## Components and their purposes

For detailed explanations and examples of each component, please refer to the [Extension Development](./extension_development.md) documentation, and to [Stacks](./stacks.md) for how the stacks are wired.

### Get

The Get component of any extension is responsible for retrieving existing secrets from a credential management system. This could be systems like Vault, AWS Secrets Manager, or any other supported secret storage service.

The engine also provides two placeholder credentials, `none/none` and `TBD/TBD` (username and secret equal to the name), that consumers can reference before the real credential exists.

### Rotate

The output of the Rotate component is the same as the Get component, a map of secrets usable by other components. However, the Rotate component also signals that the framework itself is responsible for the lifecycle of the secret.

The rotation engine uses a **dual-phase mechanism** to ensure zero-downtime credential rotation:

- Every rotation stack runs its extension as two module instances, **phase 1** and **phase 2**. With expiry `E` (`expires_in`) and rotation window `W` (`rotation_window`, default 20% of `E`), starting at `t0`:
  - phase 1 exists in `[t0, t0 + E)` and `[t0 + 2E - W, t0 + 2E)`,
  - phase 2 exists in `[t0 + E - W, t0 + 2E)`,
  - consumers get the phase 2 credential in `[t0 + E - W, t0 + 2E - W)` and the phase 1 credential otherwise.
- So the old and the new credential are both valid for `W` around every switch. Each credential is handed out for `E` and exists for `E + W`, plus the delay until the scheduled run that rotates it.
- Credentials whose service enforces an expiry must therefore be valid for `expires_in + rotation_window`, not just `expires_in`: otherwise, from the second switch on, the previous credential expires exactly when consumers switch away from it, and the overlap is lost. The bundled extensions do this (see [Extension Development](./extension_development.md#rotation)).
- Each switch happens at the first run after its boundary, and that delay comes out of the overlap: schedule runs at intervals well under half of `W`.
- `modules/rotation_schedule` tracks the `2E` cycle with `time_rotating` and `plantimestamp()` decides which phases currently exist (the arithmetic is in `modules/rotation_schedule/phases`, unit tested with `tofu test`). These resources use `create_before_destroy`; see [the ADR](./adr/20260303-fix-circular-dependency-in-rotation-lifecycle.md) for why.
- Each stack's `schedule` output shows the cycle start and which phases are active.
- Rotation is time driven: run the rotation stacks on a schedule together with their dependents (`terramate run --tags rotation --include-all-dependents ...`, see [Quick Start](./quick_start.md#scheduled-rotation)). A consumer sees a new credential once the rotation stack has been applied.

### Deployment

The Deployment component is responsible for taking secrets and deploying them to target systems. This could involve updating configuration files, environment variables, or any other method of injecting secrets into applications or services.

A Store component (storing secrets in a credential management system) is wired in the same way as a Deployment; the difference is only organizational.
