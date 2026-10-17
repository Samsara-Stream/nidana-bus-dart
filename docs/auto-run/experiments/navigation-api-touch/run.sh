#!/usr/bin/env bash
# navigation-api-touch: checks the S19 touch of navigation-api@v1 within v1:
#   - G1 gains a clause and reject/resolved_intent_is_never_a_deep_link.dart
#     two lines: a DeepLink published to nav.resolved-intent, through a
#     Publisher and publisher-less, does not compile (bus-api@v1 G40);
#   - Refinements 8 and 9, G14 and G24 cite bus-api@v1 G22, G34 and G40;
#   - Validation names flutter-binding@v1's binding of the executor suite.
# Only the reject file changes among the fixtures. The question is whether
# the touch is compatible: every fixture as it stood before the touch passes
# against a stand-in that meets bus-api@v1 as amended, the amended fixtures
# pass too, and flutter-binding@v1's executor binding is unaffected.
#
# Stand-ins, copied unchanged from ../flutter-binding-fixtures/ (T0 shows
# it): nidana_dart_contracts, nidana_contract_check (its structure and reject
# prototypes), nidana_dart_runtime and nidana_dart_navigation (both those of
# ../bus-api-amendment/: the connection rule of bus-api@v1's amendment (a)
# and the typed publish (b)), and nidana_dart_runtime_flutter
# (flutter-binding@v1).
#
# Fixture trees, each copied to hsdd/ in turn at the repository's relative
# paths:
#   before/  hsdd/contract/ at commit 6843dc2, the commit this touch starts
#            from (git archive);
#   after    the repository's hsdd/contract/ as it stands.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
BASE=6843dc2
F=hsdd/contract/fixture
N=$F/navigation-api
B=$F/flutter-binding
RT=packages/nidana_dart_runtime/lib/src
step() { echo; echo "### $*"; }

# use {tree}: makes hsdd/ a copy of the contracts and the fixtures of that tree.
use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$N "$1"/$B $F/
}

# pairs {file}: the (line severity code) triples the analyzer reports in a file.
pairs() {
  fvm dart analyze --format=json "$1" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      const ds = JSON.parse(s).diagnostics.map(d => [d.location.range.start.line, d.severity, d.code]);
      ds.sort((a, b) => a[0] - b[0]);
      for (const d of ds) console.log(d.join(" "));
    });'
}

# replay {label}: every navigation-api@v1 set, and flutter-binding@v1's
# binding of the executor suite, against the tree now at hsdd/.
replay() {
  step "$1.1 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
  for s in navigation-api flutter-binding; do
    echo "-- $s"; fvm dart run nidana_contract_check:structure_check $s | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
  done
  step "$1.2 surface: navigation-api@v1's surface libraries analyze with no diagnostic under --fatal-infos"
  fvm dart analyze --fatal-infos $N/surface; echo "exit: $?"
  step "$1.3 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
  fvm dart run nidana_contract_check:reject_check $N/reject; echo "exit: $?"
  echo "-- the raw diagnostics of resolved_intent_is_never_a_deep_link.dart (line severity code)"
  pairs $N/reject/resolved_intent_is_never_a_deep_link.dart
  step "$1.4 the conformance libraries and the bindings of both contracts analyze clean (warnings included)"
  fvm dart analyze --fatal-infos $N/behavior $B/behavior; echo "exit: $?"
  step "$1.5 behavior: navigation-api@v1's two bindings under fvm dart test, flutter-binding@v1's executor binding under fvm flutter test --no-pub"
  for b in $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
    echo "-- $b"; fvm dart test "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
  done
  echo "-- $B/behavior/flutter_navigation_executor_test.dart"
  fvm flutter test --no-pub $B/behavior/flutter_navigation_executor_test.dart 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
}

step "setup: the before tree from git, resolve"
rm -rf before && mkdir -p before
git -C $REPO archive $BASE hsdd/contract | tar -x -C before
echo "before: hsdd/contract at $(git -C $REPO rev-parse --short $BASE)"
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version

step "T0 the stand-in packages are those of ../flutter-binding-fixtures/, unchanged; their publish signatures"
for p in nidana_dart_contracts nidana_contract_check nidana_dart_runtime nidana_dart_navigation nidana_dart_runtime_flutter; do
  diff -rq -x .dart_tool ../flutter-binding-fixtures/packages/$p packages/$p > /dev/null && echo "$p: identical" || echo "$p: DIFFERS"
done
grep -n "void publish<" $RT/bus.dart

step "T1 probe: what a publish to nav.resolved-intent accepts (line severity code); a tagged line with no triple compiles"
pairs probe/resolved_intent_publish.dart
grep -n '// Q[0-9][0-9]' probe/resolved_intent_publish.dart

step "T2 what the touch changed: the fixture trees and the contracts, before against after"
use before
mv hsdd hsdd-before
use $REPO
diff -ru hsdd-before/contract/fixture hsdd/contract/fixture; echo "fixture diff exit: $?"
diff -q hsdd-before/contract hsdd/contract | sed 's/^Files \(.*\) and .* differ$/changed: \1/'
rm -rf hsdd-before

use before
replay "B (before the touch)"

use $REPO
replay "A (after the touch)"

step "T3 the amended ADR-001 structure prototype over the repository's nine contracts (item 3 coverage, item 9 layout)"
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart; echo "exit: $?")

# mutate {file} {label} {from} {to} {command...}: applies one textual defect
# to the stand-in, runs the command, and restores the file.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"; shift 4
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  grep -n "void publish<" "$file"
  "$@"
  mv "$file.orig" "$file"
}

step "T4 seeded defect: both publish paths with the signature before bus-api@v1's amendment, publish<T>(MultiWriterTopic<T> topic, T value)"
echo "-- after the touch: the new lines lose their diagnostic, only their file fails"
mutate $RT/bus.dart "Bus.publish and Publisher.publish infer T from the value too (bus-api@v1 G40 broken)" \
  "void publish<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value) {" \
  "void publish<T>(MultiWriterTopic<T> topic, T value) {" \
  fvm dart run nidana_contract_check:reject_check $N/reject
use before
echo "-- before the touch: the same defect passes navigation-api@v1's reject set, which did not pin G40"
mutate $RT/bus.dart "Bus.publish and Publisher.publish infer T from the value too (bus-api@v1 G40 broken)" \
  "void publish<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value) {" \
  "void publish<T>(MultiWriterTopic<T> topic, T value) {" \
  fvm dart run nidana_contract_check:reject_check $N/reject
grep -n "void publish<" $RT/bus.dart
echo "restored the stand-in"

step "cleanup: remove the copied trees and the Flutter build output; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd before build; echo "removed"
