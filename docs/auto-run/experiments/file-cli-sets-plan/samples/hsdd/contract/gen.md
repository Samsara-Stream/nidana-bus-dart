---
id: gen
version: v1
status: stable
kind: file
---

# gen@v1

## Guarantees / invariants

- **G1** generate writes the expected tree.
- **G2** generate exits 2 on a usage error and writes nothing.
- **G3** generate prints where it wrote and the directory it ran from.
- **G4** generate reads its input relative to the directory it runs from.
- **G5** a case's files analyze as recorded.

## Validation

- file: `hsdd/contract/fixture/gen/input/` holds `word.txt`; the replay runs `fvm dart run gen:generate {input}/word.txt {output}`, formats the Dart in `{output}` and compares `{output}` with `expected/`. The file set covers G1.
- invocations: one directory per case under `hsdd/contract/fixture/gen/invocation/`.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `analyze-lib` | `dart analyze --format=machine .` | 2 | G5 |
| `generate-from-files` | `gen:generate word.txt {output}` | 0 | G4: from files/ |
| `generate-tree` | `gen:generate --echo hsdd/contract/fixture/gen/input/word.txt {output}` | 0 | G1, G3 |
| `generate-usage` | `gen:generate --frob {output}` | 2 | G2 |
