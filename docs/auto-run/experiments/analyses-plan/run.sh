#!/usr/bin/env bash
# analyses-plan: runtime facts the nidana.model.12 plan depends on (S143).
# It replays the plan's task sequence in a temporary copy of the committed
# tree (git archive HEAD), with the files drafted under draft/, and records
# what each task's failing step and passing step print:
#   S1: the committed tree: the package tests and every replay the gate runs.
#   B: every diagnostic the analyzer reports in the Dart libraries of every
#      slug's surface/, reject/ and behavior/, before any body lands.
#   T1 to T4: each task's failing step (its new test file, and the replay of
#      its guarantees) and its passing step (the formatter, the package
#      tests, the root analyzer, the same replay). Each task's
#      lib/src/analysis/analyses.dart is derived by variants.py from
#      draft/analyses.src.dart, whose "//@ N" lines name the task that writes
#      each chunk; the stubs of later tasks stay as HEAD has them.
#   F: facts: F1 how deep the cycle search goes (facts/ring_depth_test.dart,
#      run against the final draft and against a recursive variant), F2 what
#      the generated graphs reach over the 500 seeds
#      (facts/generator_stats_test.dart), F3 how long the new test files take.
#   X: the new files against draft/ after the formatter.
#   G: the phase gate exactly as the phase context writes it.
#   U: the topology-ir behavior set unrestricted (which cases wait for
#      nidana.model.13 and nidana.model.14).
#   C: the last task's checklist.
#   A: every fixture diagnostic again, compared with B.
#   D: seeded defects (defects.py), each restored after, and which check
#      catches each.
# draft/ is evidence, not code to copy; the plan states what each task does.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/anp.XXXXXX")
V=$(mktemp -d "${T%/}/anp-v.XXXXXX") # variants, outside the analyzed tree
P=$WS/packages/nidana_dart_contracts
A=$P/lib/src/analysis/analyses.dart
RESTRICTION=G2,G3,G5,G6,G7,G8,G9,G10,G11,G12,G13,G14,G15,G16,G17,G18,G23
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-400; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  echo "PASS structure lines: $(grep -c '^PASS structure' "$WS/replay.out")"
  grep -E '^FAIL|^PENDING|^PASS behavior|fixtures:|^exit:' "$WS/replay.out" | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
tests() {
  (cd "$WS" && fvm dart test "$@" > "$WS/tests.out" 2>&1; echo "exit: $?" >> "$WS/tests.out")
  echo "-- dart test $*"
  grep -E '\[E\]$|All tests passed|Some tests failed|No tests ran|^exit:' "$WS/tests.out" | sed 's/^[0-9:]* //' | sort -u | clip | head -n 40
  grep -E "^  (UnimplementedError|Expected|Actual|Which|Error: |Bad state|Unsupported)|Error: Couldn't resolve|Error: Method not found|Error: Undefined name|Error: The getter" "$WS/tests.out" | sort | uniq -c | clip | head -n 12
}
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 12 | clip; echo "analyze exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format packages/nidana_dart_contracts 2>&1 | tail -n 1 | clip); }
put() { mkdir -p "$(dirname "$P/$1")"; cp "$DRAFT/$1" "$P/$1"; }
fixture_diagnostics() { # every (file, line, code) the analyzer reports in the fixtures' Dart sets
  (cd "$WS" && fvm dart analyze --format=json $(ls -d hsdd/contract/fixture/*/surface hsdd/contract/fixture/*/reject hsdd/contract/fixture/*/behavior 2>/dev/null) 2>/dev/null) \
    | sed -n 's/^.*\({"version".*\)$/\1/p' \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const r=j.diagnostics.map(d=>d.location.file.split("/hsdd/contract/fixture/")[1]+":"+d.location.range.start.line+" "+d.code);r.sort();console.log(r.join("\n"))})'
}
GATE="fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee $RESTRICTION"
gate() {
  (cd "$WS" && bash -c "$1" > "$WS/gate.out" 2>&1; echo "gate exit: $?")
  grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed|^FAIL|^PENDING|^PASS behavior' "$WS/gate.out" | sed 's/^[0-9][0-9]:[0-9][0-9] //' | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
seed() { # seed <label> <defect>
  local label=$1 defect=$2
  cp "$A" "$WS/seed.bak"
  echo "-- $label"
  python3 -I "$HERE/defects.py" "$A" "$defect" || { echo "   SEED FAILED"; cp "$WS/seed.bak" "$A"; return; }
  (cd "$WS" && fvm dart test packages/nidana_dart_contracts > "$WS/d.out" 2>&1)
  echo "   package tests: $(grep -E 'All tests passed|Some tests failed' "$WS/d.out" | tail -n 1 | sed 's/^[0-9:]* //' | cut -c1-60)"
  grep -E '\[E\]$' "$WS/d.out" | sed 's/^[0-9:]* +[0-9]* -[0-9]*: //; s/ \[E\]$//' | sort -u | sed 's/^/   failing: /' | cut -c1-220
  (cd "$WS" && fvm dart run nidana_contract_check topology-ir --guarantee $RESTRICTION > "$WS/d.out" 2>&1)
  echo "   gate topology-ir replay: $(grep -E '^(PASS|FAIL) behavior' "$WS/d.out" | sed 's/^.*: cases/cases/; s/^.*: \([0-9]* passed\)/\1/; s/; failed-case (/ | /g' | cut -c1-400)"
  cp "$WS/seed.bak" "$A"
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
python3 -I "$HERE/variants.py" "$DRAFT/analyses.src.dart" "$A" "$V"
for t in 1 2 3; do
  cp "$V/analyses.t$t.dart" "$V/fmt.dart"; fvm dart format "$V/fmt.dart" > /dev/null 2>&1
  cmp -s "$V/fmt.dart" "$V/analyses.t$t.dart" && echo "analyses.t$t.dart is formatter-stable" || echo "analyses.t$t.dart CHANGES under the formatter"
done

step "S1 the committed tree"
tests packages/nidana_dart_contracts
replay topic-model topology-dsl
replay topology-ir --guarantee $RESTRICTION
echo "stubs left under lib/src/analysis/: $(grep -c 'throw UnimplementedError()' "$A")"

step "B every fixture diagnostic before any body lands (surface, reject and behavior of every slug)"
fixture_diagnostics > "$WS/fixtures.before"
echo "diagnostics: $(wc -l < "$WS/fixtures.before" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.before" | sort -u | wc -l | tr -d ' ') libraries"

step "T1.2 Task 1's failing step: test/src/analysis_support.dart, test/topology_cycles_test.dart and the G13 cases"
put test/src/analysis_support.dart
put test/topology_cycles_test.dart
tests packages/nidana_dart_contracts/test/topology_cycles_test.dart
replay topology-ir --set behavior --guarantee G13

step "T1.4 Task 1's library: findTopologyCycles"
cp "$V/analyses.t1.dart" "$A"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G13

step "T2.2 Task 2's failing step: test/self_references_test.dart and the G14 cases"
put test/self_references_test.dart
tests packages/nidana_dart_contracts/test/self_references_test.dart
replay topology-ir --set behavior --guarantee G14

step "T2.4 Task 2's library: findSelfReferences"
cp "$V/analyses.t2.dart" "$A"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G14

step "T3.2 Task 3's failing step: test/ownership_test.dart and the G15 and G16 cases"
put test/ownership_test.dart
tests packages/nidana_dart_contracts/test/ownership_test.dart
replay topology-ir --set behavior --guarantee G15,G16

step "T3.4 Task 3's library: findWriterConflicts and findScopeViolations"
cp "$V/analyses.t3.dart" "$A"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G15,G16

step "T4.2 Task 4's failing step: test/analyze_graph_test.dart and the G3, G7, G17, G18 and G23 cases"
put test/analyze_graph_test.dart
tests packages/nidana_dart_contracts/test/analyze_graph_test.dart
replay topology-ir --set behavior --guarantee G3,G7,G17,G18,G23

step "T4.4 Task 4's library: analyzeTopologyGraph and findTopicNameCollisions"
cp "$V/analyses.dart" "$A"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G3,G7,G17,G18,G23
replay topology-ir --guarantee $RESTRICTION
echo "stubs left under lib/src/analysis/: $(grep -c 'throw UnimplementedError()' "$A")"

step "F1 how deep the cycle search goes under dart test: the final draft, then a recursive variant"
cp "$HERE/facts/ring_depth_test.dart" "$P/test/ring_depth_test.dart"
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/ring_depth_test.dart -j 1 2>&1 | grep -E '^F1|tests passed|failed' | sed 's/^[0-9:]* //' | clip)
cp "$A" "$WS/final.bak"
python3 -I - "$A" <<'PY'
import sys
# The recursive form of the same search: visit() calls itself for each
# unvisited successor, so its depth is the longest chain of arcs.
p = sys.argv[1]
s = open(p).read()
start = s.index("List<List<int>> _components(List<List<int>> arcs) {")
end = s.index("\n}\n", start) + 3
recursive = """List<List<int>> _components(List<List<int>> arcs) {
  final List<int?> order = List<int?>.filled(arcs.length, null);
  final List<int> low = List<int>.filled(arcs.length, 0);
  final List<bool> open = List<bool>.filled(arcs.length, false);
  final List<int> stack = <int>[];
  final List<List<int>> components = <List<int>>[];
  int visited = 0;
  void visit(int v) {
    order[v] = low[v] = visited++;
    stack.add(v);
    open[v] = true;
    for (final int w in arcs[v]) {
      if (order[w] == null) {
        visit(w);
        low[v] = low[w] < low[v] ? low[w] : low[v];
      } else if (open[w]) {
        low[v] = order[w]! < low[v] ? order[w]! : low[v];
      }
    }
    if (low[v] == order[v]) {
      final List<int> component = <int>[];
      int w;
      do {
        w = stack.removeLast();
        open[w] = false;
        component.add(w);
      } while (w != v);
      components.add(component);
    }
  }

  for (int v = 0; v < arcs.length; v++) {
    if (order[v] == null) {
      visit(v);
    }
  }
  return components;
}
"""
open(p, "w").write(s[:start] + recursive + s[end:])
PY
echo "-- the recursive variant"
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/ring_depth_test.dart -j 1 2>&1 | grep -E '^F1|tests passed|failed' | sed 's/^[0-9:]* //' | clip)
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/topology_cycles_test.dart 2>&1 | grep -E '\[E\]$|All tests passed|Some tests failed|Stack Overflow|StackOverflow' | sed 's/^[0-9:]* //' | sort -u | clip | head -n 6)
rm "$P/test/ring_depth_test.dart"
replay topology-ir --guarantee $RESTRICTION
cp "$HERE/facts/ring_depth_test.dart" "$P/test/ring_depth_test.dart"
cp "$WS/final.bak" "$A"
rm "$P/test/ring_depth_test.dart"

step "F2 what the generated graphs reach over the 500 seeds (the property tests' floors)"
cp "$HERE/facts/generator_stats_test.dart" "$P/test/generator_stats_test.dart"
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/generator_stats_test.dart 2>&1 | grep -E '^F2|tests passed|failed' | sed 's/^[0-9:]* //' | clip)
rm "$P/test/generator_stats_test.dart"

step "F3 how long the new test files take, one file at a time"
for f in topology_cycles_test self_references_test ownership_test analyze_graph_test; do
  s=$(date +%s)
  (cd "$WS" && fvm dart test "packages/nidana_dart_contracts/test/$f.dart" > /dev/null 2>&1)
  echo "$f: $(( $(date +%s) - s )) s wall, compile included"
done
s=$(date +%s); (cd "$WS" && fvm dart test packages/nidana_dart_contracts > /dev/null 2>&1); echo "the package's tests: $(( $(date +%s) - s )) s wall"

step "X the new files against draft/ (formatter-stable)"
for f in test/src/analysis_support.dart test/topology_cycles_test.dart test/self_references_test.dart test/ownership_test.dart test/analyze_graph_test.dart; do
  cmp -s "$P/$f" "$DRAFT/$f" && echo "same: $f" || { echo "DIFFERS: $f"; diff "$DRAFT/$f" "$P/$f" | head -n 30; }
done
cmp -s "$A" "$V/analyses.dart" && echo "same: lib/src/analysis/analyses.dart (variants.py's final)" || { echo "DIFFERS: analyses.dart"; diff "$V/analyses.dart" "$A" | head -n 30; }
echo "-- files changed against HEAD"
for f in $(cd "$P" && find lib test -type f | sort); do
  git -C "$REPO" cat-file -e "HEAD:packages/nidana_dart_contracts/$f" 2>/dev/null || { echo "A $f"; continue; }
  git -C "$REPO" show "HEAD:packages/nidana_dart_contracts/$f" | cmp -s - "$P/$f" || echo "M $f"
done

step "G the phase gate, exactly as the phase context writes it"
gate "$GATE"

step "U the topology-ir behavior set unrestricted"
replay topology-ir --set behavior

step "C the last task's checklist"
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(3|7|13|14|15|16|17|18|23) ' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/topology_cycles_test.dart packages/nidana_dart_contracts/test/self_references_test.dart packages/nidana_dart_contracts/test/ownership_test.dart packages/nidana_dart_contracts/test/analyze_graph_test.dart -j 1 -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/analysis; echo "exit: $?")
(cd "$WS" && grep -rnE "^(import|export) " packages/nidana_dart_contracts/lib/src/analysis/analyses.dart)
echo "-- lines: library, then tests"
(cd "$WS" && echo "lib/src/analysis/analyses.dart: $(git -C "$REPO" show HEAD:packages/nidana_dart_contracts/lib/src/analysis/analyses.dart | wc -l | tr -d ' ') at HEAD, $(wc -l < "$A" | tr -d ' ') after")
(cd "$P" && wc -l test/src/analysis_support.dart test/topology_cycles_test.dart test/self_references_test.dart test/ownership_test.dart test/analyze_graph_test.dart)

step "A every fixture diagnostic after this phase's bodies, compared with B"
fixture_diagnostics > "$WS/fixtures.after"
echo "diagnostics: $(wc -l < "$WS/fixtures.after" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.after" | sort -u | wc -l | tr -d ' ') libraries"
diff "$WS/fixtures.before" "$WS/fixtures.after" > /dev/null && echo "same as B" || { echo "DIFFERS from B:"; diff "$WS/fixtures.before" "$WS/fixtures.after" | head -n 20; }
echo "const sets or maps in the new test files:"
(cd "$P/test" && grep -nE 'const <[^>]*>\{|const \{' src/analysis_support.dart topology_cycles_test.dart self_references_test.dart ownership_test.dart analyze_graph_test.dart; echo "grep exit: $?")
echo "hash values pinned in the new test files (hashCode, then a literal):"
(cd "$P/test" && grep -nE 'hashCode, *[0-9]' src/analysis_support.dart topology_cycles_test.dart self_references_test.dart ownership_test.dart analyze_graph_test.dart; echo "grep exit: $?")

step "D seeded defects, each restored after"
seed "D1 cycles in the order the search completes them, not by first id" d1
seed "D2 a cycle's topics include a member's own self-read" d2
seed "D3 self-reference edges: every edge a read reaches, once some write of the topic is reachable" d3
seed "D4 a read matches only when it has no dedup argument" d4
seed "D5 every time stage mediates, whatever its duration" d5
seed "D6 scope violations keep the repeats of equal owners" d6
seed "D7 scope violations by owner in graph order: topologies, then claims" d7
seed "D8 findScopeViolations returns a growable list" d8
seed "D9 writer conflicts count equal claims once" d9
seed "D10 collisions count a repeated declaration twice" d10
seed "D11 collisions in the order their names were first met" d11
seed "D12 self-references by topology in reverse graph order" d12
seed "D13 arcs only through state topics" d13
seed "D14 a cycle's topics passed with repeats, one per writer and reader pair" d14

step "done"
rm -rf "$WS" "$V"
