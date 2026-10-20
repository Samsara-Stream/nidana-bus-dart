#!/usr/bin/env bash
# bus-api-v2, G9 replay: S67 (hsdd-contract, H7d of the v0.15.1 intake, with
# the orchestrator's G9 clarification, DEC-813) restates bus-api@v2 G9 so
# that the TopicRemoved a forced removal raises at a topology read follows
# topology-dsl@v2's Errors and lineage and Write chains rules, as G41's
# TypeError already does: it carries no lineage, a catchError on its path
# recovers it with Lineage.root(), and otherwise it ends every write chain
# it reaches. One case pins it. The rest of the step moves comment citations
# of bus-testing@v1 to @v2 in the three behavior files.
#
# Runtimes, as in run.sh, swapped into packages/nidana_dart_runtime/lib/src/:
# v2 (runtime/v2/, at rest in packages/), v1 and barrier-min. Two seeded
# defects in the v2 runtime stand for the readings the new case excludes:
#   regardless  catchError passes a TopicRemoved on, so a forced removal ends
#               every write chain the read reaches, recovered or not (G9 as
#               worded before S67, read literally);
#   lineage     the TopicRemoved carries the lineage of the last value the
#               read delivered, so a recovered value continues that flow.
#
# Fixture trees, each copied to hsdd/ in turn: hsdd-before/ is hsdd/contract
# at HEAD (git archive), the tree this step starts from; "after" is the
# repository's hsdd/contract as it stands.
#
# Run from anywhere: ./run-g9.sh > output-g9.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
A=$F/bus-api
API=$A/behavior/nidana_dart_runtime_test.dart
LIVE=$A/behavior/bus_activation_test.dart
RT=packages/nidana_dart_runtime/lib/src
NEW='G9 the TopicRemoved a forced removal raises at a topology read'
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$A "$1"/$F/bus-testing "$1"/$F/navigation-api "$1"/$F/flutter-binding "$1"/$F/topology-dsl $F/
}

runtime() { cp runtime/"$1"/bus.dart runtime/"$1"/interpreter.dart $RT/; }

suite() {
  echo "-- $*"
  fvm dart test --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

# why {name prefix}: the first lines of the new case's failure.
why() {
  echo "-- why: $1"
  fvm dart test --plain-name "$1" $API 2>&1 \
    | grep -E 'Expected|Actual|Which' | head -n 6
}

# mutate {label} {file} {from} {to} [{from} {to}]...: textual defects in the
# v2 runtime, the bus-api suite run, the file restored.
mutate() {
  local label="$1" file="$2"; shift 2
  cp "$file" "$file.orig"
  while [ $# -ge 2 ]; do
    FROM="$1" TO="$2" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
    shift 2
  done
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "== seeded defect: $label"
  diff "$file.orig" "$file" | grep -c '^[<>]' | sed 's/^/lines changed: /'
  suite $API
  why "$NEW"
  mv "$file.orig" "$file"
}

step "setup: the before tree from git HEAD, versions, the v2 runtime at rest"
rm -rf hsdd-before && mkdir hsdd-before
git -C $REPO archive HEAD hsdd/contract | tar -x -C hsdd-before
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version
for f in bus interpreter; do
  cmp -s runtime/v2/$f.dart $RT/$f.dart && echo "$RT/$f.dart: same as runtime/v2/$f.dart"
done

step "T1 the fixture change: case names before and after, and the other files"
use $REPO
grep -cE "^    name: 'G" hsdd-before/$A/behavior/bus_api_conformance.dart | sed 's/^/cases before: /'
grep -cE "^    name: 'G" $A/behavior/bus_api_conformance.dart | sed 's/^/cases after: /'
diff <(grep -oE "^    name: '[^']*'" hsdd-before/$A/behavior/bus_api_conformance.dart) \
     <(grep -oE "^    name: '[^']*'" $A/behavior/bus_api_conformance.dart) | grep -E '^[<>]'
echo "-- lines changed per file of the fixture tree"
for f in $(cd $A && find . -name '*.dart' | sort); do
  n=$(diff hsdd-before/$A/$f $A/$f | grep -c '^[<>]')
  [ "$n" != 0 ] && echo "$f: $n"
done
echo "-- changed lines outside the conformance library"
for f in behavior/bus_activation_test.dart behavior/nidana_dart_runtime_test.dart; do
  diff hsdd-before/$A/$f $A/$f | grep '^[<>]'
done

step "T2 structure (prototype) for bus-api, S17's prototype over the repository's contracts, analysis"
fvm dart run nidana_contract_check:structure_check bus-api | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check bus-api | grep -c '^PASS G' | sed 's/^/guarantees covered: /'
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)
fvm dart analyze --fatal-infos $A/surface; echo "surface exit: $?"
fvm dart run nidana_contract_check:reject_check $A/reject; echo "reject exit: $?"
fvm dart analyze --fatal-infos $A/behavior; echo "behavior exit: $?"

step "T3 the bus-api suite after, on each runtime"
for r in v2 v1 barrier-min; do runtime $r; echo "== runtime $r"; suite $API; done
runtime v2

step "T4 the bus-api suite before, on runtime v2"
use hsdd-before
suite $API
use $REPO

step "T5 topology-dsl@v2's live suite through bus_activation_test.dart, on v2"
suite $LIVE

step "T6 seeded defects in the v2 runtime"
mutate "regardless: catchError passes a TopicRemoved on" $RT/interpreter.dart \
  "        onError: (Object e, StackTrace st) =>
            _guard(out, _lineageOf(e), () => stage.recover(_unwrap(e), st))));" \
  "        onError: (Object e, StackTrace st) => e is TopicRemoved
            ? out.addError(e, st)
            : _guard(out, _lineageOf(e), () => stage.recover(_unwrap(e), st))));"
mutate "lineage: the TopicRemoved carries the lineage of the read's last value" $RT/interpreter.dart \
  "      void emit(_D<Object?> d) {
        final env = d.envelope;
        final lineage = env == null || topic.tracing == Tracing.disabled
            ? const Lineage.root()
            : Lineage.causedBy(env);" \
  "      Lineage? seen;
      void emit(_D<Object?> d) {
        final env = d.envelope;
        final lineage = env == null || topic.tracing == Tracing.disabled
            ? const Lineage.root()
            : Lineage.causedBy(env);
        seen = lineage;" \
  "          .add(cell.reads.stream.listen(receive, onError: out.addError));" \
  "          .add(cell.reads.stream.listen(receive,
              onError: (Object e, StackTrace st) =>
                  out.addError(seen == null ? e : _Raised(e, seen!), st)));"

step "cleanup: restore the v2 runtime, remove the copied trees"
runtime v2
for f in bus interpreter; do
  cmp -s runtime/v2/$f.dart $RT/$f.dart && echo "$RT/$f.dart: same as runtime/v2/$f.dart"
done
rm -rf hsdd hsdd-before build; echo "removed"
