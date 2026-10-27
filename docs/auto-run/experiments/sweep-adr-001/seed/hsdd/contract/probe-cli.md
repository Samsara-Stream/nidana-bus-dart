---
id: probe-cli
version: v1
status: stable
kind: cli
---

# probe-cli@v1

A probe slug of `docs/auto-run/experiments/sweep-adr-001/`, seeded into a temporary copy of the workspace only.

## Guarantees / invariants

- **G1** facts prints how it was started.
- **G2** quiet runs, its plugins line carrying a comment.
- **G3** quiet runs, its plugins line plain.
- **G4** the first row of a case named twice.
- **G5** covered only by the second row of that case.
- **G6** a command whose package is absent.
- **G7** a case whose exit_code cannot be read.

## Validation

- invocations: one directory per case under `hsdd/contract/fixture/probe-cli/invocation/`.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `facts` | `probe_tool:facts` | 0 | G1 |
| `plugin-comment` | `probe_tool:quiet` | 0 | G2 |
| `plugin-plain` | `probe_tool:quiet` | 0 | G3 |
| `dup` | `probe_tool:quiet` | 0 | G4 |
| `absent` | `absent_pkg:run` | 0 | G6 |
| `bad-exit` | `probe_tool:quiet` | 0 | G7 |
| `dup` | `probe_tool:quiet` | 0 | G5 |
