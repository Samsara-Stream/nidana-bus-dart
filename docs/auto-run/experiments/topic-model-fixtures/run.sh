#!/usr/bin/env bash
# topic-model-fixtures: replays the topic-model@v1 fixtures, as written under
# the repository's hsdd/contract/, against a stand-in of nidana_dart_contracts
# that implements the contract's Interface (packages/nidana_dart_contracts).
#
# The repository has no pub workspace yet, so the fixtures are copied into
# this experiment's own workspace, at the same relative paths, together with
# hsdd/contract/fixture/analysis_options.yaml and the contract file. The
# replay tool's structure and reject sets are prototyped in
# packages/nidana_contract_check/bin.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
step() { echo; echo "### $*"; }

step "setup: copy the fixtures and the contract from the repository, resolve"
rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/topic-model.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/topic-model $F/
find hsdd -type f | sort
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  (meta|matcher|test|lints):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock

step "T0 the stand-in package is clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 workspace-wide analyze at the root skips hsdd/** (reject fixtures hold deliberate errors)"
fvm dart analyze --fatal-infos; echo "exit: $?"

step "T2 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check topic-model; echo "exit: $?"

step "T2b structure, negative control: a guarantee with no fixture and no not-executable line fails"
cp hsdd/contract/topic-model.md hsdd/contract/topic-model.md.orig
perl -0pi -e 's/(- \*\*G26\*\* [^\n]*\n)/$1- **G27** An uncovered statement added by the negative control.\n/' hsdd/contract/topic-model.md
fvm dart run nidana_contract_check:structure_check topic-model | grep -E 'G27|PROBLEM'; echo "exit: ${PIPESTATUS[0]}"
mv hsdd/contract/topic-model.md.orig hsdd/contract/topic-model.md

step "T3 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $F/topic-model/surface; echo "exit: $?"

step "T4 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
fvm dart run nidana_contract_check:reject_check $F/topic-model/reject; echo "exit: $?"

step "T5 reject: the raw diagnostics behind T4, one line each (line severity code)"
for f in $F/topic-model/reject/*.dart; do
  echo "-- $(basename "$f")"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      for (const d of JSON.parse(s).diagnostics)
        console.log(d.location.range.start.line, d.severity, d.code);
    });'
done

step "T6 behavior: the binding under dart test, run from the root"
fvm dart test --reporter expanded $F/topic-model/behavior/nidana_dart_contracts_test.dart 2>&1 | tail -n 60; echo "exit: ${PIPESTATUS[0]}"

step "T7 behavior: a guarantee restriction by test-name prefix (--guarantee topic-model/G19)"
fvm dart test --reporter expanded --name '^G19 ' $F/topic-model/behavior/nidana_dart_contracts_test.dart 2>&1 | tail -n 12; echo "exit: ${PIPESTATUS[0]}"

step "T8 the binding is analyzed clean too (warnings included)"
fvm dart analyze --fatal-infos $F/topic-model/behavior; echo "exit: $?"

step "T9 the suite is not vacuous: each seeded defect in the stand-in fails the cases of its guarantee"
LIB=packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart
BACKUP="$LIB.orig"
cp $LIB "$BACKUP"
mutate() {
  local label="$1" from="$2" to="$3"
  cp "$BACKUP" $LIB
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' $LIB
  if cmp -s "$BACKUP" $LIB; then echo "-- $label: MUTATION DID NOT APPLY"; return; fi
  echo "-- $label"
  fvm dart test $F/topic-model/behavior/nidana_dart_contracts_test.dart 2>&1 \
    | grep -E '\[E\]$|Some tests failed|All tests passed' \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
}
mutate "taint at publish (G14)" "sensitive: topic.sensitive," "sensitive: topic.sensitive || lineage.sensitive,"
mutate "fresh correlation for a shared one (G19)" "if (correlations.length == 1) {" "if (correlations.length == 0) {"
mutate "observeAll admits sensitive envelopes (G23)" "capabilities.contains(sensitive ? observeSensitive : observeAll)" "capabilities.contains(observeAll) || capabilities.contains(observeSensitive)"
mutate "sensitive flag in topic identity (G7)" "other.name == name &&" "other.name == name && other.sensitive == sensitive &&"
mutate "parents kept by reference (G4)" "parentCorrelationIds = List<String>.unmodifiable(parentCorrelationIds);" "parentCorrelationIds = parentCorrelationIds;"
mutate "four-segment names accepted (G11)" "segments.length <= 3" "segments.length <= 4"
mutate "sensitive payload rendered in toString (G15)" "final shown = sensitive ? RedactedPayload.of(payload) : payload;" "final shown = payload;"
mutate "factory called twice per call (G9)" "return compute == null ? _initial as T : compute();" "return compute == null ? _initial as T : (compute(), compute()).\$2;"
cp "$BACKUP" $LIB && rm -f "$BACKUP"
echo "stand-in restored"

step "T10 a member added to an observer interface fails the surface set (the 'declares only' half of G22)"
cp $LIB "$LIB.orig"
perl -0pi -e 's/(abstract interface class ObserveContext \{\n)/$1  void publish(TopicRef topic, Object? value);\n/' $LIB
grep -c 'void publish(TopicRef topic' $LIB
fvm dart analyze --fatal-infos --format=machine $F/topic-model/surface | cut -d'|' -f3,4,5,6 ; echo "exit: ${PIPESTATUS[0]}"
mv "$LIB.orig" $LIB
echo "stand-in restored"

step "cleanup: remove the copied tree; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd; echo "removed"
