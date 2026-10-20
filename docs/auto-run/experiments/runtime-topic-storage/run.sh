#!/usr/bin/env bash
# runtime-topic-storage: S78 (hsdd-spec touch of nidana.runtime, H10 of the
# v0.15.1 intake). Guide v0.15.1 §6.1: "A Dart bus that implements the
# barrier keeps its own topic storage and fan-out, or wraps each subject,
# and uses RxDart for operators." nidana.runtime D3 chooses between them.
#
# Runtimes, each swapped into packages/nidana_dart_runtime/lib/src/:
#   v2     ../bus-api-v2/runtime/v2/: the wrapped subject. A cell keeps a
#          sync: true RxDart subject, which serves the observed
#          subscriptions made after start() (their first values are the
#          subject's replay, one microtask after listen), beside a
#          synchronous broadcast controller for the topology reads and the
#          subscriptions start() connects, whose first values the bus emits
#          from the subject's value; the cell also keeps the current value
#          and the buffer itself.
#   owned  runtime/owned/: topic storage and fan-out owned by the bus. The
#          same runtime with the subject removed: the cell holds the current
#          value or the buffer with their envelopes and one synchronous
#          broadcast controller; the bus emits every first value itself, for
#          a subscription made after start() in a provider-zone microtask it
#          queues at listen. RxDart serves the time-dependent stages only.
#          Every change is marked "runtime-topic-storage".
#
# The stand-in packages are ../flutter-binding-v0151/packages/ as they rest
# there (the v2 runtime, navigation-api-v0151's navigation stand-in "once",
# flutter-binding-v0151's adapter v2 with NidanaModule), copied at setup and
# removed at cleanup; the fixtures are the repository's hsdd/contract as it
# stands.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
V2=../bus-api-v2
BASE=../flutter-binding-v0151/packages
F=hsdd/contract/fixture
A=$F/bus-api
B=$F/bus-testing
N=$F/navigation-api
FB=$F/flutter-binding
API=$A/behavior/nidana_dart_runtime_test.dart
LIVE=$A/behavior/bus_activation_test.dart
RT=packages/nidana_dart_runtime/lib/src
step() { echo; echo "### $*"; }

runtime() {
  case "$1" in
    v2) cp $V2/runtime/v2/bus.dart $V2/runtime/v2/interpreter.dart $RT/ ;;
    owned) cp runtime/owned/bus.dart runtime/owned/interpreter.dart $RT/ ;;
  esac
}

suite() {
  echo "-- $*"
  fvm dart test --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

fsuite() {
  echo "-- $* (fvm flutter test)"
  fvm flutter test --no-pub --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

# mutate {file} {label} {from} {to}: one textual change in the owned
# runtime, the bus-api suite and bus-testing's suite run, the file restored.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "== $label"
  suite $API
  suite $B/behavior/nidana_dart_runtime_test.dart
  mv "$file.orig" "$file"
}

step "setup: the stand-in packages from $BASE, the fixtures, resolve, versions"
rm -rf packages hsdd
mkdir packages && (cd $BASE && tar -cf - --exclude .dart_tool .) | (cd packages && tar -xf -)
mkdir -p $F
cp $REPO/hsdd/contract/*.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$A $REPO/$B $REPO/$N $REPO/$FB $REPO/$F/topology-dsl $F/
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version
for f in bus interpreter; do
  cmp -s $RT/$f.dart $V2/runtime/v2/$f.dart && echo "copied package $f.dart: same as $V2/runtime/v2/$f.dart"
done
echo "-- lines the owned runtime changes against v2"
for f in bus interpreter; do
  diff -u $V2/runtime/v2/$f.dart runtime/owned/$f.dart | grep -c '^[+-][^+-]' | sed "s/^/$f.dart: /"
done
echo "-- RxDart names left in the owned runtime's cell and observe code (expect none)"
sed -n '/^final class _Cell/,/^bool _sameDeclaration/p;/^final class _ObserveStream/,/^final class _PendingSubscription/p' runtime/owned/bus.dart \
  | grep -cE 'Subject|rxdart|Rx\.' | sed 's/^/matches: /'

step "T1 the owned runtime and the probe analyze clean"
runtime owned
fvm dart analyze --fatal-infos packages; echo "stand-in exit: $?"
fvm dart analyze --fatal-infos probe/first_delivery.dart; echo "probe exit: $?"

step "T2 probe: first values on each runtime (G17, G34)"
for r in v2 owned; do runtime $r; echo "== runtime $r"; fvm dart run probe/first_delivery.dart; done

step "T2b probe P5: an add to a synchronous broadcast controller while it delivers (SDK only)"
fvm dart analyze --fatal-infos probe/broadcast_reentrant.dart; echo "probe exit: $?"
fvm dart run probe/broadcast_reentrant.dart

step "T3 probe: cost of one delivery to three subscriptions and one read, three runs each"
for r in v2 owned; do
  runtime $r; echo "== runtime $r"
  for i in 1 2 3; do fvm dart run probe/first_delivery.dart --cost; done
done

step "T4 bus-api@v2's suite on each runtime"
for r in v2 owned; do runtime $r; echo "== runtime $r"; suite $API; done

step "T5 topology-dsl@v2's live suite through bus_activation_test.dart, on each runtime"
for r in v2 owned; do runtime $r; echo "== runtime $r"; suite $LIVE; done

step "T6 every other suite that imports nidana_dart_runtime, on each runtime"
for r in v2 owned; do
  runtime $r; echo "== runtime $r"
  suite $B/behavior/nidana_dart_runtime_test.dart
  suite $N/behavior/nidana_dart_navigation_test.dart
  suite $N/behavior/in_memory_router_test.dart
  fsuite $FB/behavior/nidana_dart_runtime_flutter_test.dart
  fsuite $FB/behavior/flutter_navigation_executor_test.dart
done

step "T7 a check, then seeded defects in the owned runtime's first delivery, which fail the cases of what they break"
runtime owned
echo "-- check, not a defect: the bus adds a later subscription's first values during listen; a Dart"
echo "-- stream delivers nothing during listen, so they still arrive after it returns and every case passes"
mutate $RT/bus.dart "check: first values added during listen" \
  "      var ready = t is! StateTopic<T> && t is! ReplayTopic<T>;" "      var ready = true;
      first.forEach(receive);"
mutate $RT/bus.dart "seeded defect: the deliveries made before the first-value microtask are dropped" \
  "(d) => ready ? receive(d) : held.add(d)," "(d) => ready ? receive(d) : null,"
mutate $RT/bus.dart "seeded defect: the first values read when the microtask runs, not at listen" \
  "          if (cancelled) return;
          first.forEach(receive);" "          if (cancelled) return;
          cell.firstValues.forEach(receive);"
mutate $RT/bus.dart "seeded defect: an event topic subscription made after start waits for the microtask" \
  "      var ready = t is! StateTopic<T> && t is! ReplayTopic<T>;" "      var ready = false;"
mutate $RT/bus.dart "seeded defect: a bootstrap subscription's first values skipped at start" \
  "        cell.firstValues.forEach(receive);
        // The removal error" "        // The removal error"

step "cleanup: remove the copied packages, the fixtures and the build output"
rm -rf packages hsdd build .suite.log; echo "removed"
