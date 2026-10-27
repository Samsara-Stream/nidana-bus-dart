#!/usr/bin/env bash
# behavior-set-plan: runtime facts the nidana.model.6 plan (S118) depends on
# and the governance does not state.
#   T: the dart running the tool, the flutter beside it, and what the pinned
#      Flutter SDK holds on this machine (engine artifacts); what
#      `flutter test` of that SDK accepts and passes on, read from its
#      flutter_tools source (no flutter command is run: the SDK has no
#      engine artifacts, and fetching them is outside the run's network rule).
#   W: a temporary pub workspace with a stand-in package `sample`, a stand-in
#      `nidana_contract_check` (fixture.dart's typedef) and a stand-in
#      `flutter_test` (testWidgets over package:test), resolved offline.
#   D: what `dart test --reporter json` prints and exits with, from the
#      workspace root, over bindings under hsdd/contract/fixture/: all cases,
#      anchored name filters, a filter that admits none, a binding of another
#      slug's suite, a binding that does not compile, one that imports an
#      absent package, one with no case, one whose main throws.
#   F: a stand-in Flutter SDK (bin/flutter and bin/cache/dart-sdk/bin/dart,
#      shell scripts over the real dart) running a testWidgets binding.
#   U: the FormatException utf8.decode gives for a source that is not UTF-8.
#   P: the plan's own seeded samples (its Task 3 strings in a workspace seeded
#      as its Task 5 seeds it): what each binding reports under dart test, and
#      the structure set of the tool as it stands over them.
#   R: the committed bindings nidana.model's packages implement, run from the
#      repository root as the behavior set would: does each load, and what
#      does each failing case fail on.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
step() { echo; echo "### $*"; }
now() { python3 -c 'import time; print(time.time())'; }
secs() { python3 -c 'import sys,time; print("seconds: %.1f" % (time.time() - float(sys.argv[1])))' "$1"; }
summ() { python3 -I "$HERE/summarize.py" "$@"; }

step "T1 toolchain"
fvm dart --version
fvm dart run exe.dart | sed "s#$HOME#~#g"
DART=$(fvm dart run exe.dart | sed -n 's/^Platform.resolvedExecutable: //p')
SDK=$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$DART")")")")")
echo "Flutter SDK holding that dart: ${SDK/#$HOME/~}"

step "T2 engine artifacts of that Flutter SDK on this machine"
for d in bin/cache/pkg/sky_engine bin/cache/artifacts/engine; do
  if [ -e "$SDK/$d" ]; then echo "$d: present"; else echo "$d: absent"; fi
done
ls "$HOME/.pub-cache/hosted/pub.dev" | grep -E '^(test|test_api|test_core|matcher|vector_math|characters|material_color_utilities)-' | tr '\n' ' '; echo

step "T3 flutter_tools 3.47.7 source: test command options and what it hands package:test"
FT="$SDK/packages/flutter_tools/lib/src"
grep -n "'name',\|splitCommas: false\|allowed: <String>\['compact'\|No pubspec.yaml file found\|packageConfig\['test_api'\]" "$FT/commands/test.dart" | head -n 8
grep -n "\['-r', 'json'\] else if (reporter\|\['--name', name\]\|testFiles.map((Uri uri) => uri.toString())\|test.main() sets dart:io's exitCode\|return exitCode;" "$FT/test/runner.dart" | head -n 8
grep -n "testPath = globals.fs.path.absolute(testPath)" "$FT/commands/test.dart"
grep -n "throwToolExit(null, exitCode: result)" "$FT/commands/test.dart"

T=${TMPDIR:-/tmp}; WS=$(mktemp -d "${T%/}/bsp.XXXXXX")
F=hsdd/contract/fixture
mkdir -p "$WS/packages/sample/lib" "$WS/packages/nidana_contract_check/lib" "$WS/packages/flutter_test/lib" \
  "$WS/$F/sample/behavior" "$WS/$F/host/behavior"
cat > "$WS/pubspec.yaml" <<'Y'
name: stand_in_workspace
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/sample
  - packages/nidana_contract_check
  - packages/flutter_test
Y
cat > "$WS/packages/sample/pubspec.yaml" <<'Y'
name: sample
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
dependencies:
  matcher: any
dev_dependencies:
  test: any
Y
cat > "$WS/packages/sample/lib/sample.dart" <<'Y'
int twice(int n) => n * 2;
int unimplemented() => throw UnimplementedError('unimplemented');

final class Box {
  const Box(this.n);
  final int n;
}
Y
cat > "$WS/packages/nidana_contract_check/pubspec.yaml" <<'Y'
name: nidana_contract_check
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
Y
cat > "$WS/packages/nidana_contract_check/lib/fixture.dart" <<'Y'
typedef ConformanceCase<H> = ({String name, Future<void> Function(H harness) body});
Y
cat > "$WS/packages/flutter_test/pubspec.yaml" <<'Y'
name: flutter_test
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
dependencies:
  test: any
Y
cat > "$WS/packages/flutter_test/lib/flutter_test.dart" <<'Y'
import 'package:test/test.dart' show test;

export 'package:test/test.dart';

final class WidgetTester {
  const WidgetTester._();
}

void testWidgets(String description, Future<void> Function(WidgetTester tester) body) =>
    test(description, () => body(const WidgetTester._()));
Y
cat > "$WS/$F/sample/behavior/sample_conformance.dart" <<'Y'
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:sample/sample.dart';

abstract interface class SampleHarness {
  Future<void> settle();
}

final List<ConformanceCase<SampleHarness>> sampleConformance = <ConformanceCase<SampleHarness>>[
  (name: 'G1 twice doubles', body: (SampleHarness h) async => expect(twice(2), 4)),
  (name: 'G2 a second passing case', body: (SampleHarness h) async {}),
  (name: 'G25 a name a G2 filter must not admit', body: (SampleHarness h) async {}),
  (name: 'G3 an expectation fails', body: (SampleHarness h) async => expect(twice(2), 5)),
  (name: 'G4 a body throws UnimplementedError', body: (SampleHarness h) async => unimplemented()),
  (name: 'G5 equality is identity', body: (SampleHarness h) async => expect(const Box(1), Box(1))),
];
Y
cat > "$WS/$F/sample/behavior/sample_impl_test.dart" <<'Y'
import 'package:test/test.dart';

import 'sample_conformance.dart';

final class _Harness implements SampleHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
Y
sed -e "s#import 'package:test/test.dart';#import 'package:flutter_test/flutter_test.dart';#" \
    -e "s#test(c.name, () => c.body(_Harness()));#testWidgets(c.name, (WidgetTester tester) => c.body(_Harness()));#" \
    "$WS/$F/sample/behavior/sample_impl_test.dart" > "$WS/$F/sample/behavior/widget_impl_test.dart"
sed -e "s#import 'sample_conformance.dart';#import '../../sample/behavior/sample_conformance.dart';#" \
    "$WS/$F/sample/behavior/sample_impl_test.dart" > "$WS/$F/host/behavior/host_impl_test.dart"
cat > "$WS/$F/sample/behavior/broken_test.dart" <<'Y'
import 'package:test/test.dart';

void main() {
  test('G1 never runs', () => undefinedName());
}
Y
cat > "$WS/$F/sample/behavior/absent_test.dart" <<'Y'
import 'package:producer/producer.dart';
import 'package:test/test.dart';

void main() {
  test('G1 never runs', () => Producer());
}
Y
cat > "$WS/$F/sample/behavior/empty_test.dart" <<'Y'
import 'package:test/test.dart';

void main() {}
Y
cat > "$WS/$F/sample/behavior/throws_test.dart" <<'Y'
import 'package:test/test.dart';

void main() {
  throw StateError('a case list that fails to build');
}
Y

step "W1 resolve the temporary workspace offline with the dart of T1 (no fvm inside it)"
t=$(now); (cd "$WS" && "$DART" pub get --offline > "$WS/.pubget.log" 2>&1; echo "pub get --offline exit: $?"); secs "$t"
tail -n 2 "$WS/.pubget.log"
python3 -I -c 'import json,sys; print("configured packages:", ", ".join(sorted(p["name"] for p in json.load(open(sys.argv[1]))["packages"] if p["name"] in ("flutter_test","matcher","nidana_contract_check","sample","test","test_api"))))' "$WS/.dart_tool/package_config.json"

run_dart() { # label, then dart test arguments
  local label=$1; shift
  step "$label: dart test --reporter json $*"
  local t; t=$(now)
  (cd "$WS" && "$DART" test --reporter json "$@" > "$WS/.out" 2> "$WS/.err"; echo "exit: $?")
  secs "$t"
  summ < "$WS/.out"
  echo "stderr lines: $(wc -l < "$WS/.err" | tr -d ' ')"; head -n 2 "$WS/.err" | sed 's/^/  ! /'
}
cat > "$WS/$F/sample/behavior/raw_test.dart" <<'Y'
import 'package:test/test.dart';

void main() {
  test('G1 passes', () {});
  test('G2 fails', () => expect(1, 2));
  test('G3 throws', () => throw UnimplementedError('x'));
  test('G4 skipped', () {}, skip: 'later');
  test('G5 prints', () => print('hello'));
}
Y
B=$F/sample/behavior
step "D0 the raw JSON lines of one run: a pass, an expectation failure, an error, a skip and a print"
(cd "$WS" && "$DART" test --reporter json $B/raw_test.dart 2>&1 | sed -e "s#$(cd "$WS" && pwd -P)#{ws-real}#g" -e "s#$WS#{ws}#g" -e 's/"pid":[0-9]*/"pid":{pid}/'; echo "exit: ${PIPESTATUS[0]}")
step "D0b the raw JSON lines of a binding that does not load"
(cd "$WS" && "$DART" test --reporter json $B/broken_test.dart 2>&1 | sed -e 's/"pid":[0-9]*/"pid":{pid}/'; echo "exit: ${PIPESTATUS[0]}")
run_dart "D1 every case" $B/sample_impl_test.dart
run_dart "D2 anchored filter for G2" --name '^(G2) ' $B/sample_impl_test.dart
run_dart "D3 anchored filter for G2 and G5" --name '^(G2|G5) ' $B/sample_impl_test.dart
run_dart "D4 a filter that admits no case" --name '^(G9) ' $B/sample_impl_test.dart
run_dart "D5 a binding of another slug's suite, imported by ../../sample/behavior/" --name '^(G1) ' $F/host/behavior/host_impl_test.dart
run_dart "D6 a binding that does not compile" $B/broken_test.dart
run_dart "D7 a binding that imports an absent package" $B/absent_test.dart
step "D6b and D7b the whole error text of a load failure, first five lines"
for b in broken absent; do
  (cd "$WS" && "$DART" test --reporter json $B/${b}_test.dart 2>/dev/null) | python3 -I -c 'import json,sys
for l in sys.stdin:
    e=json.loads(l)
    if e["type"]=="error": print("\n".join("  > "+x for x in e["error"].splitlines()[:5]))'
done
run_dart "D8 a binding that registers no case" $B/empty_test.dart
run_dart "D9 a binding whose main throws" $B/throws_test.dart
run_dart "D10 the testWidgets binding over the stand-in flutter_test, under dart test" --name '^(G2) ' $B/widget_impl_test.dart

step "F1 a stand-in Flutter SDK: bin/flutter and bin/cache/dart-sdk/bin/dart are scripts over the real dart"
FAKE=$(mktemp -d "${T%/}/bsp-sdk.XXXXXX")
mkdir -p "$FAKE/bin/cache/dart-sdk/bin"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$DART" > "$FAKE/bin/cache/dart-sdk/bin/dart"
cat > "$FAKE/bin/flutter" <<Y
#!/bin/sh
# Records its arguments, then runs \`flutter test --no-pub ARGS\` as \`dart test ARGS\`.
printf '%s\n' "\$*" >> "\$0.calls"
[ "\$1" = test ] && [ "\$2" = --no-pub ] || { echo "stand-in flutter: expected test --no-pub" >&2; exit 64; }
shift 2
exec "$DART" test "\$@"
Y
chmod +x "$FAKE/bin/flutter" "$FAKE/bin/cache/dart-sdk/bin/dart"
FD="$FAKE/bin/cache/dart-sdk/bin/dart"
echo "flutter beside the stand-in dart, four directories up: $(dirname "$(dirname "$(dirname "$(dirname "$FD")")")")/flutter == $FAKE/bin/flutter"
t=$(now)
(cd "$WS" && "$FAKE/bin/flutter" test --no-pub --reporter json --name '^(G2|G5) ' $B/widget_impl_test.dart > "$WS/.out" 2> "$WS/.err"; echo "exit: $?")
secs "$t"
summ < "$WS/.out"
echo "recorded call: $(sed "s#$WS#{ws}#g" "$FAKE/bin/flutter.calls")"
step "F2 the stand-in dart script runs dart test like the real one"
(cd "$WS" && "$FD" test --reporter json --name '^(G1) ' $B/sample_impl_test.dart > "$WS/.out" 2>&1; echo "exit: $?")
summ < "$WS/.out" | tail -n 2

step "F3 what a dart test run leaves in the workspace root"
(cd "$WS" && ls -A | tr '\n' ' '; echo; ls -A .dart_tool | tr '\n' ' '; echo)

rm -rf "$WS" "$FAKE"

run_repo() { # label, binding path
  step "$1: fvm dart test --reporter json $2 (from the repository root)"
  local t; t=$(now)
  (cd "$REPO" && fvm dart test --reporter json "$2" > "$HERE/.out" 2> "$HERE/.err"; echo "exit: $?")
  secs "$t"
  summ --kinds < "$HERE/.out"
  echo "stderr lines: $(wc -l < "$HERE/.err" | tr -d ' ')"
  rm -f "$HERE/.out" "$HERE/.err"
}
step "R0 the repository at"
git -C "$REPO" log -1 --format='%h %s'
run_repo "R1 topic-model@v1's binding" hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart
run_repo "R2 topology-dsl@v2's recording binding" hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart
run_repo "R3 topology-ir@v1's binding" hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart
step "R4 case names the fixture reader would read: lines holding a name: string literal per conformance library"
for f in topic-model/behavior/topic_model_conformance.dart topology-dsl/behavior/recording_conformance.dart topology-ir/behavior/topology_ir_conformance.dart topology-dsl/behavior/live_conformance.dart; do
  echo "$f: $(grep -cE "^\s*name: '" "$REPO/$F/$f")"
done
step "R6 the case names the tool's fixture reader reads (readDartLibrary), per conformance library: count, and whether every one begins with G{n} and a space"
(cd "$REPO" && fvm dart run "$HERE/reader.dart" $F/topic-model/behavior/topic_model_conformance.dart $F/topology-dsl/behavior/recording_conformance.dart $F/topology-ir/behavior/topology_ir_conformance.dart $F/topology-dsl/behavior/live_conformance.dart $F/bus-api/behavior/bus_api_conformance.dart $F/navigation-api/behavior/navigation_executor_conformance.dart)
step "R5 does any committed conformance library import package:test or package:flutter_test"
grep -lE "^import 'package:(test|flutter_test)/" "$REPO"/$F/*/behavior/*_conformance.dart || echo "none"
step "U1 what utf8.decode reports for the bytes the plan's tests seed as a Dart source that is not UTF-8"
fvm dart run "$HERE/utf8.dart"
step "R7 every committed binding's relative imports, its runner by a package:flutter_test import, and which conformance libraries no binding imports"
python3 -I - "$REPO" <<'PY'
import os, re, sys, glob
repo = sys.argv[1]
os.chdir(repo)
bound = set()
for b in sorted(glob.glob("hsdd/contract/fixture/*/behavior/*_test.dart")):
    src = open(b, encoding="utf-8").read()
    uris = re.findall(r"^import '([^']+)'", src, re.M)
    rel = [u for u in uris if ":" not in u]
    resolved = [os.path.normpath(os.path.join(os.path.dirname(b), u)) for u in rel]
    bound.update(resolved)
    runner = "flutter test --no-pub" if any(u.startswith("package:flutter_test/") for u in uris) else "dart test"
    print("%s: %s; relative imports %s" % (b, runner, resolved))
libs = sorted(glob.glob("hsdd/contract/fixture/*/behavior/*_conformance.dart"))
print("conformance libraries no binding imports: %s" % ([l for l in libs if l not in bound] or "none"))
PY

step "P1 the plan's behavior samples (Task 3) in a workspace seeded as Task 5 seeds it, under dart test (the command the stand-in flutter of F1 runs)"
T=${TMPDIR:-/tmp}; PW=$(mktemp -d "${T%/}/bsp-plan.XXXXXX")
mkdir -p "$PW/packages/sample/lib" "$PW/packages/nidana_contract_check/lib" "$PW/packages/flutter_test/lib" "$PW/$F/sample/behavior" "$PW/$F/host/behavior"
printf 'name: stand_in_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/sample\n  - packages/nidana_contract_check\n  - packages/flutter_test\n' > "$PW/pubspec.yaml"
printf 'name: sample\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\ndependencies:\n  matcher: any\ndev_dependencies:\n  test: any\n' > "$PW/packages/sample/pubspec.yaml"
cat > "$PW/packages/sample/lib/sample.dart" <<'Y'
/// The stand-in package the replay tool's tests analyze fixtures against.
library;

/// A class other libraries may construct but never extend.
final class Sample {
  const Sample();

  /// A final field: assigning it reports `assignment_to_final`.
  final int count = 0;
}
Y
printf 'name: nidana_contract_check\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n' > "$PW/packages/nidana_contract_check/pubspec.yaml"
cat > "$PW/packages/nidana_contract_check/lib/fixture.dart" <<'Y'
/// Stands in for package:nidana_contract_check/fixture.dart in a seeded workspace.
library;

typedef ConformanceCase<H> = ({
  String name,
  Future<void> Function(H harness) body,
});
Y
printf 'name: flutter_test\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\ndependencies:\n  test: any\n' > "$PW/packages/flutter_test/pubspec.yaml"
cat > "$PW/packages/flutter_test/lib/flutter_test.dart" <<'Y'
/// Stands in for package:flutter_test in a seeded workspace: testWidgets over package:test.
library;

import 'package:test/test.dart' show test;

export 'package:test/test.dart';

/// Stands in for flutter_test's WidgetTester.
final class WidgetTester {
  const WidgetTester._();
}

/// Registers [description] as a test whose body is given a [WidgetTester].
void testWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => test(description, () => body(const WidgetTester._()));
Y
cat > "$PW/$F/sample/behavior/sample_conformance.dart" <<'Y'
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:sample/sample.dart';

abstract interface class SampleHarness {
  Future<void> settle();
}

final List<ConformanceCase<SampleHarness>> sampleConformance =
    <ConformanceCase<SampleHarness>>[
  (
    name: 'G2 a sample counts from zero',
    body: (SampleHarness h) async => expect(const Sample().count, 0),
  ),
  (name: 'G2 a second case of G2', body: (SampleHarness h) async {}),
  (
    name: 'G3 a sample is redacted',
    body: (SampleHarness h) async => expect(const Sample().count, 1),
  ),
  (
    name: 'G1 a body not implemented yet',
    body: (SampleHarness h) async => throw UnimplementedError('G1'),
  ),
];
Y
cat > "$PW/$F/sample/behavior/sample_impl_test.dart" <<'Y'
// ignore: unused_import
import 'package:sample/sample.dart';
import 'package:test/test.dart';

import 'sample_conformance.dart';

final class _Harness implements SampleHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
Y
cat > "$PW/$F/sample/behavior/widget_impl_test.dart" <<'Y'
import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:sample/sample.dart';

import 'sample_conformance.dart';

final class _Harness implements SampleHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in sampleConformance) {
    testWidgets(c.name, (WidgetTester tester) => c.body(_Harness()));
  }
}
Y
cat > "$PW/$F/host/behavior/host_impl_test.dart" <<'Y'
import 'package:test/test.dart';

import '../../sample/behavior/sample_conformance.dart';

final class _Harness implements SampleHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
Y
cat > "$PW/$F/host/behavior/broken_impl_test.dart" <<'Y'
import 'package:test/test.dart';

import '../../sample/behavior/sample_conformance.dart';

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(undefinedHarness));
  }
}
Y
(cd "$PW" && "$DART" pub get --offline > /dev/null 2>&1; echo "pub get --offline exit: $?")
plan_run() { # label, runner command..., then the binding
  echo "-- $1"; shift
  (cd "$PW" && "$@" > "$PW/.out" 2> "$PW/.err"; echo "exit: $?")
  summ < "$PW/.out" | grep -E '^(visible|  |done)'
}
plan_run "sample_impl_test.dart, every case" "$DART" test --reporter json $F/sample/behavior/sample_impl_test.dart
plan_run "sample_impl_test.dart, ^(G2) " "$DART" test --reporter json --name '^(G2) ' $F/sample/behavior/sample_impl_test.dart
plan_run "widget_impl_test.dart under dart test (the stand-in flutter runs exactly this), ^(G2) " "$DART" test --reporter json --name '^(G2) ' $F/sample/behavior/widget_impl_test.dart
plan_run "host_impl_test.dart, ^(G2|G3) " "$DART" test --reporter json --name '^(G2|G3) ' $F/host/behavior/host_impl_test.dart
plan_run "broken_impl_test.dart" "$DART" test --reporter json $F/host/behavior/broken_impl_test.dart
(cd "$PW" && "$DART" test --reporter json $F/host/behavior/broken_impl_test.dart 2>/dev/null) | python3 -I -c 'import json,sys
for l in sys.stdin:
    e=json.loads(l)
    if e["type"]=="error": print("  load error, second line: " + e["error"].splitlines()[1].replace(sys.argv[1], "{pw}"))' "$PW"
rm -rf "$PW"

step "P2 the structure set of this phase's tool base over the plan's behavior and host samples (Task 3): both slugs pass"
SW=$(mktemp -d "${T%/}/bsp-structure.XXXXXX")
mkdir -p "$SW/$F/sample/behavior" "$SW/$F/sample/reject" "$SW/$F/sample/surface" "$SW/$F/sample/goldens" "$SW/$F/host/behavior"
cat > "$SW/hsdd/contract/sample.md" <<'Y'
---
id: sample
version: v1
status: stable
kind: api
---

# sample@v1

## Guarantees / invariants

- **G1** a sample type is closed.
- **G2** a sample value round-trips.
- **G3** a sample value is redacted.
- **G4** a property of the package's pubspec.

## Validation

- surface: `hsdd/contract/fixture/sample/surface/` uses every declaration.
- reject: `hsdd/contract/fixture/sample/reject/`, one library per type-level guarantee.
- behavior: conformance library `hsdd/contract/fixture/sample/behavior/sample_conformance.dart`, cases `sampleConformance`.
- binding: `hsdd/contract/fixture/sample/behavior/sample_impl_test.dart` binds the suite, under `dart test`.
- binding: `hsdd/contract/fixture/sample/behavior/widget_impl_test.dart` binds the suite, under `testWidgets`.
- goldens: `hsdd/contract/fixture/sample/goldens/`, renderings the behavior set compares.
- not executable: G4, a property of the package's pubspec; checked by nidana.model's gates
- not executable: G3's last clause, on a value no case can build; checked by nidana.model's gates
Y
cat > "$SW/hsdd/contract/host.md" <<'Y'
---
id: host
version: v1
status: stable
kind: api
---

# host@v1

## Guarantees / invariants

- **G1** a host binds another contract's suite.

## Validation

- binding: `hsdd/contract/fixture/host/behavior/host_impl_test.dart` binds sample@v1's suite (`../../sample/behavior/sample_conformance.dart`), under `dart test`.
- not executable: G1, a property no fixture shows; checked by nidana.model's gates
Y
printf "// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: invalid_use_of_type_outside_library\nfinal class Local extends Sample {}\n" > "$SW/$F/sample/reject/sample_is_closed.dart"
printf "import 'package:sample/sample.dart';\n\nSample use() => Sample();\n" > "$SW/$F/sample/surface/use.dart"
printf 'golden\n' > "$SW/$F/sample/goldens/sample.txt"
for f in sample_conformance.dart sample_impl_test.dart widget_impl_test.dart; do
  sed -n "/^cat > \"\$PW\/\$F\/sample\/behavior\/$f\" <<'Y'$/,/^Y$/p" "$HERE/run.sh" | sed '1d;$d' > "$SW/$F/sample/behavior/$f"
done
sed -n "/^cat > \"\$PW\/\$F\/host\/behavior\/host_impl_test.dart\" <<'Y'$/,/^Y$/p" "$HERE/run.sh" | sed '1d;$d' > "$SW/$F/host/behavior/host_impl_test.dart"
(cd "$SW" && "$DART" run "$REPO/packages/nidana_contract_check/bin/nidana_contract_check.dart" sample host --set structure; echo "exit: $?")
rm -rf "$SW"
