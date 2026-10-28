---
id: probe-file
version: v1
status: stable
kind: file
---

# probe-file@v1

A probe slug of `docs/auto-run/experiments/sweep-adr-001/`, seeded into a temporary copy of the workspace only.

## Guarantees / invariants

- **G1** generate copies in.txt.

## Validation

- file: `hsdd/contract/fixture/probe-file/input/` holds `in.txt`; the replay runs `fvm dart run probe_tool:generate {input} {output}` and compares `{output}` with `expected/`, so `{output}` holds `in.txt`.
- not executable: G1, the probe declares no covers clause on purpose; checked by nidana.model's gates
