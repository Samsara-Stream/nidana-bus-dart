#!/usr/bin/env bash
# topology-ir-declarations-plan: runtime facts the nidana.model.5 plan
# depends on (S115). It replays the plan's task sequence in a temporary copy
# of the committed tree (git archive HEAD), with the files drafted under
# draft/, and records what each task's failing step and passing step print:
#   S: the committed tree: the package tests, topology-ir's surface and
#      reject sets, and this phase's gate replay, before any declaration.
#   F: the formatter on the draft files as first written with every
#      trailing comment of the Interface kept trailing (which lines it
#      splits), so the plan's blocks are its stable output.
#   T1: lib/src/graph/ and lib/src/analysis/findings.dart, with the first
#       two export directives of lib/topology_ir.dart: the declarations test
#       fails to compile, then passes; the replays.
#   T2: lib/src/analysis/analyses.dart, lib/src/json/, lib/src/render/ and
#       the rest of lib/topology_ir.dart: the exports test and the renderer
#       test fail, then everything passes.
#   G: the phase gate, as the phase context writes it, then the final
#      task's checklist.
#   R: every (line, code) pair reported in each topic-model, topology-dsl
#      and topology-ir reject library, and whether any line carries two
#      codes (the question routed from S103 to nidana.model.3 to .5).
#   D: seeded defects, each restored after: topology_ir.dart re-exporting
#      the main library, a getter in place of a final field, a finding
#      constructor that is not const. Which check catches each.
#   X: every Dart block of the plan against draft/, so that the blocks are
#      the text this dry run replayed.
# draft/ is evidence, not code to copy; the plan states the declarations.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/tird.XXXXXX")
P=$WS/packages/nidana_dart_contracts
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-260; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "PASS structure lines: $(grep -c '^PASS structure' "$WS/replay.out"), PASS schema lines: $(grep -c '^PASS schema' "$WS/replay.out")"
  grep -vE '^PASS (structure|schema)' "$WS/replay.out" | clip
}
ir_replay() { echo "-- topology-ir --set surface,reject"; replay topology-ir --set surface,reject; }
gate_replay() { echo "-- topic-model topology-dsl topology-ir --set structure,surface,reject,schema"; replay topic-model topology-dsl topology-ir --set structure,surface,reject,schema; }
tests() { (cd "$WS" && fvm dart test "$@" 2>&1 | grep -E '^\s*[0-9]+:[0-9]+ \+|Error|error|Expected|Actual|Extra|Missing|reason|Which|Some tests' | tail -n 20 | clip; echo "exit: ${PIPESTATUS[0]}"); }
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 8 | clip; echo "exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format --output=none --set-exit-if-changed packages/nidana_dart_contracts 2>&1 | tail -n 3 | clip; echo "format exit: ${PIPESTATUS[0]}"); }
put() { mkdir -p "$(dirname "$P/$2")"; cp "$DRAFT/$1" "$P/$2"; }

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)

step "S1 before any declaration of this phase"
tests packages/nidana_dart_contracts
ir_replay
gate_replay

step "F the formatter on the Interface's trailing comments kept trailing (a scratch copy, removed after)"
mkdir -p "$WS/fprobe/packages/nidana_dart_contracts/lib/src/graph" "$WS/fprobe/packages/nidana_dart_contracts/lib/src/analysis"
python3 - "$DRAFT" "$WS/fprobe/packages/nidana_dart_contracts/lib/src" <<'PY'
import re, sys, pathlib
draft, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for rel in ['graph/graph.dart', 'analysis/findings.dart']:
    text = (draft / 'lib/src' / rel).read_text()
    # a comment line followed by a field: put the comment back at the end of the field's line
    text = re.sub(r'^(  )// (.*)\n  (final [^\n]*;)$', r'\1\3 // \2', text, flags=re.M)
    (out / rel).write_text(text)
PY
(cd "$WS" && cp -R fprobe/packages/nidana_dart_contracts/lib fprobe/before && fvm dart format fprobe/packages/nidana_dart_contracts/lib > /dev/null 2>&1; diff -r fprobe/before fprobe/packages/nidana_dart_contracts/lib | clip)
rm -rf "$WS/fprobe"

step "T1.2 the declarations test, before lib/topology_ir.dart exists"
put test/topology_ir_declarations_test.t1.dart test/topology_ir_declarations_test.dart
tests packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart
echo "-- its first three error lines:"
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart 2>&1 | grep -m 3 'Error' | clip)
ir_replay

step "T1.4 lib/src/graph/graph.dart, lib/src/analysis/findings.dart and their two export directives"
put lib/src/graph/graph.dart lib/src/graph/graph.dart
put lib/src/analysis/findings.dart lib/src/analysis/findings.dart
put lib/topology_ir.t1.dart lib/topology_ir.dart
fmt
tests packages/nidana_dart_contracts
analyze
ir_replay
echo "-- surface/graphs.dart's diagnostics, one per line:"
grep 'surface/graphs.dart' "$WS/replay.out" | python3 -c 'import re, sys; [print("  " + m) for m in re.findall(r"\(line \d+: [A-Z]+ [a-z_]+: [^)]*\)", sys.stdin.read())]'
gate_replay

step "T2.2 the exports test and the renderer test, before the rest of lib/topology_ir.dart"
put test/topology_ir_declarations_test.dart test/topology_ir_declarations_test.dart
put test/exports_test.dart test/exports_test.dart
tests packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart
tests packages/nidana_dart_contracts/test/exports_test.dart

step "T2.4 lib/src/analysis/analyses.dart, lib/src/json/codec.dart, lib/src/render/renderers.dart and lib/topology_ir.dart"
put lib/src/analysis/analyses.dart lib/src/analysis/analyses.dart
put lib/src/json/codec.dart lib/src/json/codec.dart
put lib/src/render/renderers.dart lib/src/render/renderers.dart
put lib/topology_ir.dart lib/topology_ir.dart
fmt
tests packages/nidana_dart_contracts
analyze
ir_replay
gate_replay

step "G the phase gate, from the workspace root"
(cd "$WS" && bash -c 'fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema' > "$WS/gate.out" 2>&1; echo "gate exit: $?")
grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed' "$WS/gate.out" | clip

step "G2 the final task's checklist"
(cd "$WS" && grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?")
(cd "$WS" && grep -rnE "operator ==|hashCode|toString\(\)" packages/nidana_dart_contracts/lib/src/graph packages/nidana_dart_contracts/lib/src/analysis packages/nidana_dart_contracts/lib/src/json packages/nidana_dart_contracts/lib/src/render; echo "exit: $?")
(cd "$WS" && grep -nE "^(import|export) " packages/nidana_dart_contracts/lib/topology_ir.dart packages/nidana_dart_contracts/lib/src/graph/*.dart packages/nidana_dart_contracts/lib/src/analysis/*.dart packages/nidana_dart_contracts/lib/src/json/*.dart packages/nidana_dart_contracts/lib/src/render/*.dart | clip)
(cd "$WS" && grep -c "ignore: unused_element" -r packages/nidana_dart_contracts/lib | grep -v ':0$')
(cmp -s "$WS/pubspec.lock" "$REPO/pubspec.lock" && echo "pubspec.lock unchanged")
(cd "$WS" && wc -l packages/nidana_dart_contracts/lib/topology_ir.dart packages/nidana_dart_contracts/lib/src/graph/*.dart packages/nidana_dart_contracts/lib/src/analysis/*.dart packages/nidana_dart_contracts/lib/src/json/*.dart packages/nidana_dart_contracts/lib/src/render/*.dart packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart | clip)
(cd "$WS" && git -C "$REPO" show HEAD:packages/nidana_dart_contracts/test/exports_test.dart | diff - packages/nidana_dart_contracts/test/exports_test.dart | grep -c '^[<>]' | sed 's/^/exports_test.dart changed lines: /')

step "R every (line, code) pair reported in each reject library of nidana.model's three contracts; a line with two codes is flagged"
(cd "$WS" && fvm dart analyze --format=json hsdd/contract/fixture/topic-model/reject hsdd/contract/fixture/topology-dsl/reject hsdd/contract/fixture/topology-ir/reject 2>/dev/null) | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    const by = {};
    for (const d of JSON.parse(s).diagnostics) {
      const parts = d.location.file.split("/");
      const f = parts.slice(-3).join("/");
      (by[f] = by[f] || []).push([d.location.range.start.line, d.code]);
    }
    let two = 0;
    for (const f of Object.keys(by).sort()) {
      const lines = {};
      for (const [l, c] of by[f]) (lines[l] = lines[l] || new Set()).add(c);
      const t = Object.keys(lines).filter(l => lines[l].size > 1);
      two += t.length;
      console.log(f, by[f].length, "diagnostics,", t.length ? "TWO CODES ON " + t.join(",") : "one code per line");
    }
    console.log("libraries:", Object.keys(by).length, "lines with two codes:", two);
  });'

step "D seeded defects, each restored after"
seed() { # seed <label> <file> <python replace: old> <new>; then the checks named in $CHECKS
  cp "$2" "$WS/seed.bak"
  python3 - "$2" "$3" "$4" <<'PY'
import sys, pathlib
f, a, b = pathlib.Path(sys.argv[1]), sys.argv[2].encode().decode('unicode_escape'), sys.argv[3].encode().decode('unicode_escape')
t = f.read_text(); assert t.count(a) == 1, a; f.write_text(t.replace(a, b))
PY
  echo "-- $1"
}
restore() { cp "$WS/seed.bak" "$1"; }
seed "D1 topology_ir.dart also re-exports the main library" "$P/lib/topology_ir.dart" "library;\n" "library;\n\nexport 'nidana_dart_contracts.dart';\n"
analyze
ir_replay | tail -n 2
tests packages/nidana_dart_contracts/test/exports_test.dart | tail -n 4
restore "$P/lib/topology_ir.dart"
seed "D2 ShellClaim.scope a getter over a private field" "$P/lib/src/graph/graph.dart" "  final Scope scope;\n" "  Scope get scope => _scope;\n  final Scope _scope = Scope.application;\n"
ir_replay | grep -E 'ir_values_are_immutable|fixtures:'
restore "$P/lib/src/graph/graph.dart"
seed "D3 ScopeViolation's constructor not const" "$P/lib/src/analysis/findings.dart" "  const ScopeViolation({" "  ScopeViolation({"
ir_replay | tail -n 2
tests packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart | tail -n 3
restore "$P/lib/src/analysis/findings.dart"
seed "D4 TopologyFinding not sealed but abstract" "$P/lib/src/analysis/findings.dart" "sealed class TopologyFinding {" "abstract class TopologyFinding {"
ir_replay | grep -E 'ir_families_are_closed|graphs.dart|fixtures:' | cut -c1-200
restore "$P/lib/src/analysis/findings.dart"
tests packages/nidana_dart_contracts | tail -n 1

step "X every Dart block of the plan is the text of a draft file or a contiguous part of one"
python3 - "$REPO/docs/superpowers/plans/nidana.model.5.md" "$DRAFT" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.exists():
    print('no plan yet'); sys.exit(0)
plan, draft = p.read_text(), pathlib.Path(sys.argv[2])
files = {str(f.relative_to(draft)): f.read_text() for f in draft.rglob('*.dart')}
blocks = re.findall(r'```dart\n(.*?)```', plan, re.S)
for i, b in enumerate(blocks, 1):
    whole = [n for n, t in sorted(files.items()) if t == b]
    part = [n for n, t in sorted(files.items()) if b in t]
    print(f'block {i}: {len(b.splitlines())} lines,', ('the whole of ' + whole[0]) if whole else ('part of ' + part[0]) if part else 'NOT IN ANY DRAFT FILE')
PY

step "cleanup"
rm -rf "$WS"; echo "removed the temporary workspace"
