# Run the engine on Terramate stacks

- Status: accepted
- Date: 2026-11-22
- Tags: terramate, stacks, architecture

## Context and Problem Statement

The engine was one OpenTofu root module: every get, rotation and deployment config was a module instance
in one state, and the merged secret map was passed to every deployment. Consequences:

- every run plans everything, and one broken service or provider blocks all others;
- every deployment depends on every rotation, which is what caused the cycle in
  [the 2026-03-03 ADR](./20260303-fix-circular-dependency-in-rotation-lifecycle.md) (its option 3,
  selective secrets passing, was rejected then because static wiring was hard);
- every new rotated service needed hand-written `phase1`/`phase2` module pairs and output entries, and
  every provider instance had to be threaded through the root and the engine modules;
- keeping the set of credentials plan-time known required the OpenTofu-only `convert()`.

## Decision Drivers

- Minimal blast radius of a rotation and of failures
- Keep the YAML configuration format and the extension contract
- Keep the dual-phase rotation semantics and its `create_before_destroy` fix
- Less manual wiring

## Considered Options

1. Keep the single root module
2. Terramate stacks, one per credential / deployment unit, wired with outputs sharing
3. Terramate stacks wired with `terraform_remote_state` data sources

## Decision Outcome

Chosen option 2.

- `scripts/sync_stacks.py` writes one stack per get/rotation config and per deployment unit. Stack blocks
  (ids, `after`, `input`/`output`) must be static in Terramate, hence a generator script rather than pure
  Terramate configuration. It also does the validation the root module did (duplicates, missing
  producers).
- `terramate generate` produces the OpenTofu code of every stack from `stacks/engine.tm.hcl`, so the
  extension call (including the phase pair of rotations) is generated, not hand-written.
- Credentials flow through Terramate outputs sharing: each consumer imports exactly the credentials its
  configs reference. This is option 3 of the 2026-03-03 ADR, now cheap because the wiring is generated.
- The rotation schedule of one credential is `modules/rotation_schedule`; its timers keep
  `create_before_destroy`.

Option 3 was rejected because remote state reads need backend-specific wiring in every consumer and do
not give Terramate the dependency graph (`--include-all-dependents`, mocks for planning a fresh setup).

### Positive Consequences

- A rotation runs only its stack and its consumers (`--tags rotation --include-all-dependents`); changes
  run only affected stacks (`--changed --include-all-dependents`); independent stacks can run in parallel.
- New extensions and configs need no engine edits.
- No `convert()` needed, so the OpenTofu requirement drops from 1.13 to 1.12.

### Negative Consequences

- Outputs sharing is an experimental Terramate feature (`experiments = ["outputs-sharing"]`).
- A consumer's plan shows the producer's current output, not the one an upcoming apply of the producer
  will produce; a full preview of a rotation needs the producer applied first.
- One state per stack: removing a configuration needs a destroy of its stack before `--prune`.
- A Python step (`sync_stacks.py`, PyYAML) is part of the workflow, and its output must be committed. The
  committed stacks are what detects removed configurations (orphans) and what drives `--changed`. Two
  branches adding configs to the same deployment unit conflict in its `stack.tm.hcl`; resolve that by
  regenerating. See [Stacks](../stacks.md#why-the-stacks-are-committed).
- State of the previous single root module is not migrated; existing deployments need imports or a
  fresh apply.
