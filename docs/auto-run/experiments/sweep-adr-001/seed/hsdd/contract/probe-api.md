---
id: probe-api
version: v1
status: stable
kind: shared-model
---

# probe-api@v1

A probe slug of `docs/auto-run/experiments/sweep-adr-001/`, seeded into a temporary copy of the workspace only.

## Guarantees / invariants

- **G1** a case of a bound conformance library.
- **G2** a case of a conformance library no binding imports.
- **G3** a case of a conformance library that imports an absent package.
- **G4** a case of a conformance library with conditional imports.

## Validation

- binding: `hsdd/contract/fixture/probe-api/behavior/bound_test.dart` binds `bound_conformance.dart`.
- binding: `hsdd/contract/fixture/probe-api/behavior/absent_test.dart` binds `absent_conformance.dart`.
- binding: `hsdd/contract/fixture/probe-api/behavior/conditional_test.dart` binds `conditional_conformance.dart`, and imports an absent package in a configuration.
- binding: `hsdd/contract/fixture/probe-api/behavior/none_test.dart` imports no conformance library.
- binding: `hsdd/contract/fixture/probe-api/behavior/two_test.dart` imports two conformance libraries.
- `unbound_conformance.dart`: no binding imports it.
