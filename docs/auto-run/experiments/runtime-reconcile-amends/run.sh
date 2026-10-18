#!/usr/bin/env bash
# runtime-reconcile-amends: checks the three compatible amendments S31's
# hsdd-reconcile applied from nidana.runtime's phase plan:
#
# - bus-api@v1 G41 (nidana.runtime D5): a value that is not of the topic's
#   value type, reached through a widened reference, is checked by neither the
#   publish nor the delivery; a subscription's or a topology read's conversion
#   fails into the provider zone's handler and that subscription or read alone
#   skips it; a conversion at a call (getCurrentValue, getBufferedValues, a
#   reduceInto seed) throws TypeError to the caller; an activate that throws
#   activates nothing. Three new G41 cases.
# - bus-testing@v1 G16 (nidana.runtime D6): envelopesOf<T> returns an equal
#   MessageEnvelope<T> for a record of another type argument, and a payload
#   that is not a T makes the query throw TypeError. One new G16 case.
# - bus-testing@v1 G18 (nidana.runtime D7): stub keeps one publisher per
#   topic and returns its writer per type argument. One new G18 case.
#
# The stand-in under packages/ is ../bus-api-widened/packages/ copied
# unchanged, except for the patch marked "runtime-reconcile-amends patch" in
# packages/nidana_dart_runtime/lib/src/ (bus.dart, interpreter.dart,
# testing.dart). before/ keeps those three files as ../bus-api-widened/ has
# them, the stand-in before this patch.
#
# The contracts and fixtures are the repository's hsdd/contract/ as amended,
# copied into this experiment's own workspace at the same relative paths, and
# removed again. Every contract whose fixtures import nidana_dart_runtime is
# replayed: bus-api@v1 (with topology-dsl@v1's live suite through
# bus_activation_test.dart), bus-testing@v1, navigation-api@v1 (both suites)
# and flutter-binding@v1 (both bindings, under fvm flutter test).
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
A=$F/bus-api
B=$F/bus-testing
N=$F/navigation-api
FB=$F/flutter-binding
RT=packages/nidana_dart_runtime/lib/src
NEW='^G41 an off-type|^G41 the current value and the buffer hold|^G41 a topology read skips|^G16 for an envelope published through a widened|^G18 stub through a StateTopic'
step() { echo; echo "### $*"; }

# before {command...}: runs the command with before/'s three files in place of
# the patched ones, and restores the patched ones.
before() {
  for f in bus.dart interpreter.dart testing.dart; do cp $RT/$f $RT/$f.patched; cp before/$f $RT/$f; done
  "$@"
  for f in bus.dart interpreter.dart testing.dart; do mv $RT/$f.patched $RT/$f; done
}

# report {command...}: runs the command and prints its failing case names and
# its verdict.
report() {
  "$@" 2>&1 | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' \
    | grep -E '\[E\]$|Some tests failed|All tests passed' | sort -u
}

# mutate {file} {label} {from} {to} {command...}: applies one textual defect
# to the patched stand-in, runs the command, and restores the file.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"; shift 4
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  report "$@"
  mv "$file.orig" "$file"
}

api() { fvm dart test $A/behavior/nidana_dart_runtime_test.dart; }
testing() { fvm dart test $B/behavior/nidana_dart_runtime_test.dart; }
newcases() { fvm dart test --name "$NEW" $A/behavior/nidana_dart_runtime_test.dart $B/behavior/nidana_dart_runtime_test.dart; }

step "setup: copy the contracts and the fixtures from the repository, resolve"
rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/*.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$A $REPO/$B $REPO/$N $REPO/$F/topology-dsl $REPO/$FB $F/
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version
echo "-- the patch in the stand-in runtime"
grep -n "runtime-reconcile-amends patch" $RT/*.dart
echo "-- before/ equals the runtime of ../bus-api-widened/; the patched files differ from it, every other stand-in file is the same"
for f in bus.dart interpreter.dart testing.dart; do
  cmp -s before/$f ../bus-api-widened/$RT/$f && echo "before/$f: same" || echo "before/$f: DIFFERS"
  cmp -s $RT/$f ../bus-api-widened/$RT/$f && echo "$RT/$f: same" || echo "$RT/$f: patched"
done
diff -r -q -x .dart_tool -x bus.dart -x interpreter.dart -x testing.dart packages ../bus-api-widened/packages && echo "other stand-in files: same"

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports (prototype structure set)"
for s in bus-api bus-testing; do
  echo "-- $s"; fvm dart run nidana_contract_check:structure_check $s | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
done

step "T1b structure under amended ADR-001 (items 3 and 9), S17's prototype, over the repository's nine contracts"
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)

step "T2 the conformance libraries and the bindings analyze clean (warnings included)"
fvm dart analyze --fatal-infos $A/behavior $B/behavior $N/behavior $FB/behavior; echo "exit: $?"

step "T3 behavior: every suite that touches nidana_dart_runtime, on the patched stand-in"
for b in $A/behavior/nidana_dart_runtime_test.dart $A/behavior/bus_activation_test.dart $B/behavior/nidana_dart_runtime_test.dart $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
  echo "-- $b"; fvm dart test "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
done
for b in $FB/behavior/nidana_dart_runtime_flutter_test.dart $FB/behavior/flutter_navigation_executor_test.dart; do
  echo "-- $b (fvm flutter test, testWidgets)"; fvm flutter test --no-pub "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
done

step "T4 the five new cases by name, on the patched stand-in"
fvm dart test --reporter expanded --name "$NEW" $A/behavior/nidana_dart_runtime_test.dart $B/behavior/nidana_dart_runtime_test.dart 2>&1 \
  | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | grep -v '^loading'; echo "exit: ${PIPESTATUS[0]}"

step "T5 the stand-in before the patch: which cases fail"
echo "-- bus-api suite"
before report api
echo "-- bus-testing suite"
before report testing
for b in $A/behavior/bus_activation_test.dart $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
  echo "-- $b"; before bash -c "fvm dart test $b 2>&1 | tail -n 1"
done

step "T6 seeded defects in the patched stand-in fail the new cases of the guarantee they break"
mutate $RT/interpreter.dart "a topology read converts outside a guard, so the connection's TypeError escapes activate (G41)" \
  "          payload = d.payload as T;
        } catch (e, st) {
          _bus._zone.handleUncaughtError(e, st);
          return;
        }" \
  "          payload = d.payload as T;
        } finally {}" newcases
mutate $RT/bus.dart "an activate that throws while wiring stays active (G41)" \
  "    } catch (_) {
      a.deactivate();
      rethrow;
    }" \
  "    } catch (_) {
      rethrow;
    }" newcases
mutate $RT/testing.dart "envelopesOf skips a record of another type argument (G16)" \
  "        if (r.topic == ref) _typed<T>(r.unredacted)," \
  "        if (r.topic == ref && r.unredacted is MessageEnvelope<T>) r.unredacted as MessageEnvelope<T>," newcases
mutate $RT/testing.dart "envelopesOf skips a record whose payload is not a T instead of throwing (G16)" \
  "        if (r.topic == ref) _typed<T>(r.unredacted)," \
  "        if (r.topic == ref && r.unredacted.payload is T) _typed<T>(r.unredacted)," newcases
mutate $RT/testing.dart "stub makes a publisher per type argument (G18)" \
  "    final Publisher p = _stubs[topic] ??=
        publisher(testSource, writes: <StateTopic<Object?>>{topic});" \
  "    final Publisher p =
        publisher(testSource, writes: <StateTopic<Object?>>{topic});" newcases

step "cleanup: remove the copied tree and the Flutter build output; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd build; echo "removed"
