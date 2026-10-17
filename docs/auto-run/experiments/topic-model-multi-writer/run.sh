#!/usr/bin/env bash
# topic-model-multi-writer: checks the S10 amendment of topic-model@v1, a
# sealed MultiWriterTopic<T> above EventTopic<T> and ReplayTopic<T>, for
# compatibility within v1.
#
# Two stand-ins of the topic-model@v1 part of nidana_dart_contracts:
#   - after:  packages/nidana_dart_contracts/lib/src/topic_model.dart, copied
#             from ../bus-api-fixtures/, which carries MultiWriterTopic;
#   - before: standin/topic_model.before.dart, copied from
#             ../topology-ir-fixtures/, topic-model@v1 as S06 wrote it.
# The rest of the workspace (the topology-dsl@v1 and topology-ir@v1 parts of
# nidana_dart_contracts, the nidana_dart_runtime stand-in of bus-api@v1, and
# the replay tool prototypes) is copied from ../bus-api-fixtures/.
#
# Two fixture trees of topic-model@v1:
#   - before/hsdd/: the contract and fixtures at commit $BASE, the commit
#     before S10 (git archive), the fixtures every existing consumer wrote
#     against;
#   - hsdd/: the repository's working tree, the amended contract and
#     fixtures, together with the fixtures of topology-dsl@v1, topology-ir@v1
#     and bus-api@v1, the contracts that consume topic-model@v1.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
BASE=df5e8f854c885563488168e7a9ca2b34772e4570
F=hsdd/contract/fixture
BF=before/$F
TM=$F/topic-model
BTM=$BF/topic-model
LIB=packages/nidana_dart_contracts/lib/src/topic_model.dart
step() { echo; echo "### $*"; }
use_before() { cp $LIB standin/topic_model.after.tmp && cp standin/topic_model.before.dart $LIB && echo "stand-in: before (MultiWriterTopic declared: $(grep -c 'class MultiWriterTopic' $LIB))"; }
use_after() { mv standin/topic_model.after.tmp $LIB && echo "stand-in: after (MultiWriterTopic declared: $(grep -c 'class MultiWriterTopic' $LIB))"; }
raw() {
  for f in "$@"; do
    echo "-- $(basename "$f")"
    fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
      let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
        for (const d of JSON.parse(s).diagnostics)
          console.log(d.location.range.start.line, d.severity, d.code);
      });'
  done
}
sets() { # sets {fixture root} {slug}: surface and reject of one slug
  echo "-- $2 surface"
  fvm dart analyze --fatal-infos --format=machine "$1/$2/surface" | cut -d'|' -f1,3,4,5; echo "exit: ${PIPESTATUS[0]}"
  echo "-- $2 reject"
  fvm dart run nidana_contract_check:reject_check "$1/$2/reject"; echo "exit: $?"
}
tests() { # tests {binding}: one behavior binding, summary line only
  echo "-- $(basename "$1")"
  fvm dart test "$1" 2>&1 | grep -E '\[E\]$|Some tests failed|All tests passed|Error:' \
    | sed -E 's/^[0-9:]+ //' | sort -u
  echo "exit: ${PIPESTATUS[0]}"
}

step "setup: copy the trees, resolve"
rm -rf hsdd before && mkdir -p $F before
cp $REPO/hsdd/contract/topic-model.md $REPO/hsdd/contract/topology-dsl.md \
  $REPO/hsdd/contract/topology-ir.md $REPO/hsdd/contract/bus-api.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$TM $REPO/$F/topology-dsl $REPO/$F/topology-ir $REPO/$F/bus-api $F/
git -C $REPO archive $BASE hsdd/contract/topic-model.md $F/analysis_options.yaml $TM | tar -x -C before
echo "before tree from $(git -C $REPO log -1 --format='%h %s' $BASE)"
find before -type f | sort
echo "changed topic-model files, before -> after:"
diff -rq before/hsdd/contract/topic-model.md hsdd/contract/topic-model.md
diff -rq $BTM $TM
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  (meta|matcher|test|rxdart|clock|lints):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock
echo "stand-in diff, before -> after:"
diff standin/topic_model.before.dart $LIB

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 workspace-wide analyze at the root skips hsdd/**, before/**, probe/** and standin/**"
fvm dart analyze --fatal-infos; echo "exit: $?"

step "P1 probe: the diagnostic each candidate misuse of MultiWriterTopic reports (after stand-in)"
raw probe/codes.dart

echo
echo "################ A: after stand-in, topic-model@v1 fixtures as they stood before S10"

step "A1 structure, against the contract before S10"
(cd before && fvm dart run ../packages/nidana_contract_check/bin/structure_check.dart topic-model); echo "exit: $?"

step "A2 surface"
fvm dart analyze --fatal-infos $BTM/surface; echo "exit: $?"

step "A3 reject"
fvm dart run nidana_contract_check:reject_check $BTM/reject; echo "exit: $?"

step "A4 behavior: the binding under dart test"
tests $BTM/behavior/nidana_dart_contracts_test.dart

echo
echo "################ B: after stand-in, topic-model@v1 fixtures as amended"

step "B1 structure, against the amended contract"
fvm dart run nidana_contract_check:structure_check topic-model; echo "exit: $?"

step "B2 surface"
fvm dart analyze --fatal-infos $TM/surface; echo "exit: $?"

step "B3 reject"
fvm dart run nidana_contract_check:reject_check $TM/reject; echo "exit: $?"

step "B4 reject: the raw diagnostics of the two reject files S10 wrote or extended"
raw $TM/reject/topic_family_is_closed.dart $TM/reject/state_topic_is_not_multi_writer.dart

step "B5 behavior: the binding under dart test"
fvm dart test --reporter expanded $TM/behavior/nidana_dart_contracts_test.dart 2>&1 | tail -n 4; echo "exit: ${PIPESTATUS[0]}"

step "B6 behavior: the new case alone (--guarantee topic-model/G27)"
fvm dart test --reporter expanded --name '^G27 ' $TM/behavior/nidana_dart_contracts_test.dart 2>&1 | tail -n 3; echo "exit: ${PIPESTATUS[0]}"

step "B7 the binding and the conformance library analyze clean (warnings included)"
fvm dart analyze --fatal-infos $TM/behavior; echo "exit: $?"

echo
echo "################ C: after stand-in, the consumers' fixtures"

step "C1 surface and reject of topology-dsl@v1, topology-ir@v1 and bus-api@v1"
sets $F topology-dsl
sets $F topology-ir
sets $F bus-api

step "C2 behavior bindings that need no schema validator: the recorder, the bus-api suite, the live suite"
tests $F/topology-dsl/behavior/topology_builder_test.dart
tests $F/bus-api/behavior/nidana_dart_runtime_test.dart
tests $F/bus-api/behavior/bus_activation_test.dart

step "C3 inference probe (probe/lub.dart) against the after stand-in"
raw probe/lub.dart

echo
echo "################ D: before stand-in, without MultiWriterTopic"
use_before

step "D1 baseline: topic-model@v1 fixtures as they stood before S10 (surface, reject, behavior)"
fvm dart analyze --fatal-infos $BTM/surface; echo "exit: $?"
fvm dart run nidana_contract_check:reject_check $BTM/reject; echo "exit: $?"
tests $BTM/behavior/nidana_dart_contracts_test.dart

step "D2 negative control: the amended topic-model@v1 surface and reject sets fail without MultiWriterTopic"
sets $F topic-model

step "D3 topology-dsl@v1 and topology-ir@v1 give the same results as in C1; bus-api@v1 needs the amendment"
sets $F topology-dsl
sets $F topology-ir
sets $F bus-api
tests $F/topology-dsl/behavior/topology_builder_test.dart

step "D4 inference probe (probe/lub.dart) against the before stand-in"
raw probe/lub.dart

use_after

echo
echo "################ M: seeded defects in the after stand-in fail the fixtures of G1 and G27"
mutate() {
  local label="$1" from="$2" to="$3"
  cp $LIB "$LIB.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' $LIB
  if cmp -s "$LIB.orig" $LIB; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$LIB.orig" $LIB; return; fi
  step "$label"
  echo "-- surface"
  fvm dart analyze --fatal-infos --format=machine $TM/surface | cut -d'|' -f1,3,5; echo "exit: ${PIPESTATUS[0]}"
  echo "-- reject"
  fvm dart run nidana_contract_check:reject_check $TM/reject | grep -v '^PASS'; echo "exit: ${PIPESTATUS[0]}"
  tests $TM/behavior/nidana_dart_contracts_test.dart
  mv "$LIB.orig" $LIB
}
mutate "M1 MultiWriterTopic abstract instead of sealed (G1)" \
  "sealed class MultiWriterTopic<T> extends Topic<T> {" \
  "abstract class MultiWriterTopic<T> extends Topic<T> {"
mutate "M2 StateTopic a multi-writer topic (G27)" \
  "final class StateTopic<T> extends Topic<T> {" \
  "final class StateTopic<T> extends MultiWriterTopic<T> {"
echo "stand-in restored: MultiWriterTopic declared $(grep -c 'sealed class MultiWriterTopic' $LIB)"

step "cleanup: remove the copied trees; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd before; echo "removed"
