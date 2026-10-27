#!/usr/bin/env bash
# topology-dsl-declarations-plan: runtime facts the nidana.model.4 plan
# depends on (S112). It replays the plan's task sequence in a temporary copy
# of the committed tree (git archive HEAD), with the files drafted under
# draft/, and records what each task's failing step and passing step print:
#   P: analyzer facts the declarations rely on (probe/, its own pubspec):
#      which unused private constructors unused_element reports, whether an
#      implicit default constructor is const, and which URI spellings import
#      dart:io past the old directive reader.
#   S: the committed tree: the phase gate's replay and the routed RED
#      baseline (topology-dsl topology-ir --set surface,reject).
#   T1: the hardened purity test: the new self-tests against the old
#       readers, then the new readers, then seeded violations it must catch.
#   T2: the IR under lib/src/ir/: its test fails to compile, then passes;
#       the replays.
#   T3: the DSL library with the builder and handle parts: its test fails,
#       then passes; the replays.
#   T4: the plan, stage and sink parts and lib/topology_plan.dart: the
#       exports test fails, then everything passes.
#   G: the phase gate, as the phase context writes it, then the replays run
#      outside it and the final task's checklist.
#   X: every Dart block of the plan against draft/, so that the blocks are
#      the text this dry run replayed.
#   R: every (line, code) pair reported in each topology-dsl reject library,
#      and whether any line carries two codes (the routed ADR-001 item 4
#      question); the same for topology-ir's reject libraries, whose IR lines
#      this phase's declarations already decide (nidana.model.5 replays them).
# draft/ is evidence, not code to copy; the plan states the declarations.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/tddp.XXXXXX")
P=$WS/packages/nidana_dart_contracts
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-240; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "PASS structure lines: $(grep -c '^PASS structure' "$WS/replay.out")"
  grep -v '^PASS structure' "$WS/replay.out" | clip
}
gate_replay() { echo "-- topic-model topology-dsl --set structure,surface,reject"; replay topic-model topology-dsl --set structure,surface,reject; }
red_baseline() { echo "-- topology-dsl topology-ir --set surface,reject"; replay topology-dsl topology-ir --set surface,reject; }
ir_replay() { echo "-- topology-ir --set surface,reject"; replay topology-ir --set surface,reject; }
tests() { (cd "$WS" && fvm dart test "$@" 2>&1 | grep -E '^\s*[0-9]+:[0-9]+ \+|Error|error|Expected|Actual|reason|Which' | tail -n 16 | clip; echo "exit: ${PIPESTATUS[0]}"); }
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 8 | clip; echo "exit: ${PIPESTATUS[0]}"); }
seed() { # seed <file> <text>: append text, run the purity test, restore
  cp "$1" "$WS/seed.bak"
  printf '%b' "$2" >> "$1"
  echo "-- seeded into ${1#"$P"/}: $(printf '%b' "$2" | tr '\n' ' ')"
  (cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/purity_test.dart 2>&1 | grep -E ' names |Expected|Actual|lib/src/topic/scope.dart$|\+[0-9]+ -[0-9]+: Some tests failed' | tail -n 4 | clip)
  cp "$WS/seed.bak" "$1"
}

step "P analyzer facts (probe/, outside the workspace)"
rm -rf "$HERE/probe/.dart_tool" "$HERE/probe/pubspec.lock"
(cd "$HERE/probe" && cp "$REPO/.fvmrc" . && fvm dart pub get --offline > /dev/null 2>&1; fvm dart analyze 2>&1 | grep -E 'error|warning|info|issue' | sed "s#$HERE/##g")
rm -rf "$HERE/probe/.dart_tool" "$HERE/probe/pubspec.lock" "$HERE/probe/.fvmrc"

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)

step "S1 the replays before any declaration of this phase"
gate_replay
red_baseline
tests packages/nidana_dart_contracts

step "T1.2 the new self-tests against the old readers"
mkdir -p "$P/test/src"
cp "$DRAFT/test/src/package_files.dart" "$P/test/src/"
cp "$DRAFT/test/purity_test.red.dart" "$P/test/purity_test.dart"
tests packages/nidana_dart_contracts/test/purity_test.dart

step "T1.4 the new readers"
cp "$DRAFT/test/purity_test.dart" "$P/test/purity_test.dart"
tests packages/nidana_dart_contracts
analyze
(cd "$WS" && fvm dart format --output=none --set-exit-if-changed packages/nidana_dart_contracts/test 2>&1 | tail -n 1; echo "format exit: ${PIPESTATUS[0]}")

step "T1.5 seeded violations the hardened purity test catches (each restored after)"
M=$P/lib/nidana_dart_contracts.dart
seed "$M" "\nimport 'src/topic/scope.dart'\n    if (dart.library.io) 'dart:io';\n"
seed "$M" "\nimport r'dart:io';\n"
seed "$M" "\nimport 'dart:' 'io';\n"
seed "$M" "\nimport 'dart:\\\\x69o';\n"
seed "$M" "\nexport '../test/src/package_files.dart';\n"
seed "$P/lib/src/topic/scope.dart" "\npart '../../../outside.dart';\n"
seed "$M" "\nimport 'file:///etc/hosts.dart';\n"
seed "$P/lib/src/topic/scope.dart" "\n// Zone.current in a comment still counts\n"

step "T2.2 the IR test, before lib/src/ir/ exists"
cp "$DRAFT/test/ir_declarations_test.dart" "$P/test/"
tests packages/nidana_dart_contracts/test/ir_declarations_test.dart

step "T2.4 lib/src/ir/ and its exports"
mkdir -p "$P/lib/src/ir"
cp "$DRAFT/lib/src/ir/"*.dart "$P/lib/src/ir/"
cp "$DRAFT/lib/nidana_dart_contracts.t2.dart" "$M"
tests packages/nidana_dart_contracts
analyze
gate_replay
ir_replay

step "T3.2 the DSL test, before lib/src/topology/ exists"
cp "$DRAFT/test/topology_declarations_test.dart" "$P/test/"
tests packages/nidana_dart_contracts/test/topology_declarations_test.dart

step "T3.4 the DSL library with its builder and handle parts, and its exports"
mkdir -p "$P/lib/src/topology"
grep -vE "^part '(plan|sinks|stages)\.dart';$" "$DRAFT/lib/src/topology/topology.dart" > "$P/lib/src/topology/topology.dart"
cp "$DRAFT/lib/src/topology/builder.dart" "$DRAFT/lib/src/topology/handle.dart" "$P/lib/src/topology/"
cp "$DRAFT/lib/nidana_dart_contracts.dart" "$M"
grep -n '^part' "$P/lib/src/topology/topology.dart"
tests packages/nidana_dart_contracts
analyze
gate_replay
ir_replay

step "T4.2 the exports test, before the plan library exists"
cp "$DRAFT/test/exports_test.dart" "$P/test/"
tests packages/nidana_dart_contracts/test/exports_test.dart

step "T4.4 the plan, stage and sink parts and lib/topology_plan.dart"
cp "$DRAFT/lib/src/topology/"*.dart "$P/lib/src/topology/"
cp "$DRAFT/lib/topology_plan.dart" "$P/lib/"
tests packages/nidana_dart_contracts
analyze
gate_replay
(cd "$WS" && fvm dart format --output=none --set-exit-if-changed packages/nidana_dart_contracts 2>&1 | tail -n 1; echo "format exit: ${PIPESTATUS[0]}")

step "G the phase gate, from the workspace root"
(cd "$WS" && bash -c 'fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject' > "$WS/gate.out" 2>&1; echo "gate exit: $?")
grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed' "$WS/gate.out" | clip

step "G2 outside the gate: topology-ir's surface and reject sets, and the routed RED baseline command"
ir_replay
red_baseline

step "G3 the final task's checklist"
(cd "$WS" && grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?")
(cd "$WS" && grep -rnE "operator ==|hashCode" packages/nidana_dart_contracts/lib/src/topology packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?")
(cd "$WS" && git -C "$REPO" diff --quiet HEAD -- pubspec.lock && cmp -s pubspec.lock "$REPO/pubspec.lock" && echo "pubspec.lock unchanged")
(cd "$WS" && find packages/nidana_dart_contracts/lib -name '*.dart' | sort | xargs wc -l | tail -n 1)
(cd "$WS" && find packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/topology packages/nidana_dart_contracts/lib/topology_plan.dart -name '*.dart' | sort | xargs wc -l)
(cd "$WS" && grep -c '^ *///' packages/nidana_dart_contracts/lib/src/ir/*.dart packages/nidana_dart_contracts/lib/src/topology/*.dart packages/nidana_dart_contracts/lib/topology_plan.dart | awk -F: '{s+=$2} END {print "dartdoc lines in the new library files:", s}')

step "R every (line, code) pair reported in each topology-dsl and topology-ir reject library; a line with two codes is flagged"
(cd "$WS" && fvm dart analyze --format=json hsdd/contract/fixture/topology-dsl/reject hsdd/contract/fixture/topology-ir/reject 2>/dev/null) | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    const by = {};
    for (const d of JSON.parse(s).diagnostics) {
      const f = d.location.file.split("/").pop();
      (by[f] = by[f] || []).push([d.location.range.start.line, d.code]);
    }
    for (const f of Object.keys(by).sort()) {
      const lines = {};
      for (const [l, c] of by[f]) (lines[l] = lines[l] || new Set()).add(c);
      const two = Object.keys(lines).filter(l => lines[l].size > 1);
      console.log(f, by[f].map(([l, c]) => l + ":" + c).join(" "), two.length ? "TWO CODES ON " + two.join(",") : "one code per line");
    }
  });'

step "X every Dart block of the plan is the text of a draft file or a contiguous part of one"
python3 - "$REPO/docs/superpowers/plans/nidana.model.4.md" "$DRAFT" <<'PY'
import re, sys, pathlib
plan, draft = pathlib.Path(sys.argv[1]).read_text(), pathlib.Path(sys.argv[2])
files = {str(f.relative_to(draft)): f.read_text() for f in draft.rglob('*.dart')}
t3 = '\n'.join(l for l in files['lib/src/topology/topology.dart'].split('\n')
                if not re.match(r"^part '(plan|sinks|stages)\.dart';$", l))
files['lib/src/topology/topology.dart (Task 3: two parts)'] = t3
blocks = re.findall(r'```dart\n(.*?)```', plan, re.S)
for i, b in enumerate(blocks, 1):
    whole = [n for n, t in files.items() if t == b]
    part = [n for n, t in files.items() if b in t]
    print(f'block {i}: {len(b.splitlines())} lines,', ('the whole of ' + whole[0]) if whole else ('part of ' + part[0]) if part else 'NOT IN ANY DRAFT FILE')
PY

step "cleanup"
rm -rf "$WS"; echo "removed the temporary workspace"
