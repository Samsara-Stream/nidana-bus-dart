#!/usr/bin/env bash
# structure-set-plan: settles the facts docs/superpowers/plans/nidana.model.1.md
# (S99) relies on and the governance does not state.
#
#   W1 to W8: nidana.model.1's root files and member pubspec, exactly as the
#     plan writes them, in a temporary copy of the repository layout (hsdd/
#     with its nested fixture pubspecs, a docs/ experiment with its own
#     pubspec): what `fvm dart pub get` writes, the versions it resolves,
#     `--enforce-lockfile`, the root analyze, `fvm dart run
#     nidana_contract_check` from the root with its exit code, `fvm dart test
#     packages/nidana_contract_check` from the root, package:args' parse of
#     the command line, and how a test runs the tool's bin script from a
#     seeded temporary directory outside the workspace.
#   S1 to S4: structure_proto.dart, the plan's structure rules (both
#     not-executable forms need their "; checked by {node}'s gates" clause,
#     ADR-001 item 3 as written), over the nine contracts as committed; over
#     a copy whose bus-api G13 line carries the clause the hsdd-contract touch
#     adds; under the first draft's lenient reading (LENIENT=1), for the
#     record; and over a copy with seeded defects.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
PROTO=$HERE/structure_proto.dart
step() { echo; echo "### $*"; }
fvm dart --version 2>&1 | tail -1

W=$(mktemp -d)
cp "$REPO/.fvmrc" "$W/.fvmrc"
cp -R "$REPO/hsdd" "$W/hsdd"
mkdir -p "$W/docs/auto-run/experiments"
cp -R "$REPO/docs/auto-run/experiments/model-gate-commands" "$W/docs/auto-run/experiments/"
printf 'void main() { int x = "not an int"; }\n' > "$W/docs/auto-run/experiments/model-gate-commands/broken.dart"
M=$W/packages/nidana_contract_check
mkdir -p "$M/bin" "$M/test"
cat > "$W/pubspec.yaml" <<'EOF'
name: nidana_workspace
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/nidana_contract_check
dev_dependencies:
  lints: ^6.1.0
EOF
cat > "$W/analysis_options.yaml" <<'EOF'
include: package:lints/recommended.yaml
analyzer:
  exclude:
    - ref/**
    - docs/**
    - hsdd/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
EOF
cat > "$M/pubspec.yaml" <<'EOF'
name: nidana_contract_check
description: Replays the contract fixtures under hsdd/contract/ (ADR-001 item 9).
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
dependencies:
  args: ^2.7.0
  json_schema: ^5.2.2
  matcher: ^0.12.20
  package_config: ^2.2.0
  path: ^1.9.1
dev_dependencies:
  test: ^1.31.1
EOF
cat > "$M/bin/nidana_contract_check.dart" <<'EOF'
import 'dart:io';

import 'package:args/args.dart';

void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addFlag('all', negatable: false)
    ..addMultiOption('set')
    ..addMultiOption('guarantee');
  try {
    final ArgResults r = parser.parse(arguments);
    stdout.writeln('all=${r.flag('all')} set=${r.multiOption('set')} '
        'guarantee=${r.multiOption('guarantee')} rest=${r.rest} '
        'cwd=${Directory.current.path}');
  } on FormatException catch (e) {
    stderr.writeln('usage error: ${e.message}');
    exitCode = 64;
    return;
  }
  exitCode = int.tryParse(Platform.environment['PROBE_EXIT'] ?? '') ?? 0;
}
EOF
cat > "$M/test/probe_test.dart" <<'EOF'
import 'dart:io';

import 'package:test/test.dart';

String _bin() =>
    '${Directory.current.path}/packages/nidana_contract_check/bin/nidana_contract_check.dart';

void main() {
  test('the working directory and the executable', () {
    print('cwd=${Directory.current.path}');
    print('resolvedExecutable=${Platform.resolvedExecutable}');
  });
  test('the bin script by absolute path, from a directory outside the workspace', () async {
    final Directory outside = Directory.systemTemp.createTempSync('ncc_probe_');
    final ProcessResult r = await Process.run(Platform.resolvedExecutable,
        <String>[_bin(), 'topic-model', '--set', 'structure,schema', '--guarantee', 'G1,topology-dsl/G5'],
        workingDirectory: outside.path);
    print('plain: exit=${r.exitCode} stdout=${(r.stdout as String).trim()} stderr=${(r.stderr as String).trim()}');
    final ProcessResult u = await Process.run(Platform.resolvedExecutable,
        <String>[_bin(), '--frobnicate'],
        workingDirectory: outside.path);
    print('unknown option: exit=${u.exitCode} stderr=${(u.stderr as String).trim()}');
    outside.deleteSync(recursive: true);
  });
}
EOF

step "W1 fvm dart pub get at the root: exit, and every file it writes outside hsdd/ and docs/"
touch "$W/.marker"; sleep 1
(cd "$W" && fvm dart pub get 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}")
(cd "$W" && find . -newer .marker -type f -not -path './hsdd/*' -not -path './docs/*' | sort | sed 's/^/  /')
echo "under hsdd/ or docs/:"; (cd "$W" && find hsdd docs -newer .marker | sed 's/^/  /'; echo "  (end)")

step "W2 resolved versions of the member's dependencies and of lints"
(cd "$W" && for p in args json_schema matcher package_config path test test_api test_core lints; do
  printf '  %-16s %s\n' "$p" "$(awk -v p="  $p:" '$0==p{f=1;next} f&&/version:/{gsub(/"/,"",$2);print $2;exit}' pubspec.lock)"; done)

step "W3 fvm dart pub get --enforce-lockfile"
(cd "$W" && fvm dart pub get --enforce-lockfile 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")

step "W4 fvm dart analyze --fatal-infos at the root (docs/ holds a type error, hsdd/ the fixtures)"
(cd "$W" && fvm dart analyze --fatal-infos 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}")

step "W5 fvm dart run nidana_contract_check from the root: arguments, working directory, exit code"
(cd "$W" && fvm dart run nidana_contract_check --all --set structure 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")
(cd "$W" && PROBE_EXIT=64 fvm dart run nidana_contract_check topic-model 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")
(cd "$W" && PROBE_EXIT=1 fvm dart run nidana_contract_check topic-model 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")
(cd "$W" && fvm dart run nidana_contract_check --frobnicate 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")

step "W6 package:args: repeated and comma-separated multi-options, options after positionals"
(cd "$W" && fvm dart run nidana_contract_check topic-model --set structure --set schema,surface topology-ir --guarantee G1 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")
(cd "$W" && fvm dart run nidana_contract_check --set 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")

step "W7 fvm dart test packages/nidana_contract_check from the root; a test runs the bin script from outside the workspace"
(cd "$W" && fvm dart test packages/nidana_contract_check 2>&1 | grep -v '^\s*$' | tail -8; echo "exit: ${PIPESTATUS[0]}")

step "W8 the same tests from inside the member"
(cd "$M" && fvm dart test 2>&1 | grep -E 'cwd=|All tests|Some tests' ; echo "exit: ${PIPESTATUS[0]}")
rm -rf "$W"

step "S1 structure_proto.dart over the nine contracts as committed (strict: both forms need the node clause)"
(cd "$REPO" && fvm dart run "$PROTO"; echo "exit: $?")

step "S2 the same over a copy whose bus-api G13 line ends with the clause the hsdd-contract touch adds"
B=$(mktemp -d)
cp "$REPO/.fvmrc" "$B/.fvmrc"
mkdir -p "$B/hsdd" && cp -R "$REPO/hsdd/contract" "$B/hsdd/"
perl -pi -e "s/^(- not executable: G13's last sentence, .*one)\$/\$1; checked by nidana.runtime's gates/" "$B/hsdd/contract/bus-api.md"
grep -n "^- not executable: G13" "$B/hsdd/contract/bus-api.md" | sed 's/^/  /'
(cd "$B" && fvm dart run "$PROTO"; echo "exit: $?")
rm -rf "$B"

step "S2b the first draft's lenient reading (a partial line may omit the clause), for the record"
(cd "$REPO" && LENIENT=1 fvm dart run "$PROTO" bus-api; echo "exit: $?")

step "S3 seeded defects in a copy that carries the bus-api touch: each must be reported, naming the path and the rule"
C=$(mktemp -d)
cp "$REPO/.fvmrc" "$C/.fvmrc"
mkdir -p "$C/hsdd" && cp -R "$REPO/hsdd/contract" "$C/hsdd/"
perl -pi -e "s/^(- not executable: G13's last sentence, .*one)\$/\$1; checked by nidana.runtime's gates/" "$C/hsdd/contract/bus-api.md"
F=$C/hsdd/contract/fixture
echo "  a. an unlisted directory: topology-dsl/goldens/"
mkdir -p "$F/topology-dsl/goldens" && touch "$F/topology-dsl/goldens/a.txt"
echo "  b. a reject file without a covers header: topic-model no_dispatcher_hint.dart (G5 then uncovered)"
sed -i '' '/^\/\/ covers: /d' "$F/topic-model/reject/no_dispatcher_hint.dart"
echo "  c. an uncovered guarantee: topic-model gains G28"
awk '{print} /^- \*\*G27\*\* /{print "- **G28** a guarantee nothing covers."}' "$C/hsdd/contract/topic-model.md" > "$C/t.md" && mv "$C/t.md" "$C/hsdd/contract/topic-model.md"
echo "  d. a listed binding that is absent: topology-ir nidana_dart_contracts_test.dart"
rm "$F/topology-ir/behavior/nidana_dart_contracts_test.dart"
echo "  e. a src/ import: topology-dsl surface/plan.dart"
printf "import 'package:nidana_dart_contracts/src/topology/topology.dart';\n" | cat - "$F/topology-dsl/surface/plan.dart" > "$C/p.dart" && mv "$C/p.dart" "$F/topology-dsl/surface/plan.dart"
echo "  f. a case name that does not begin with its id, and a topic constructor's name: in a body (not a case)"
perl -0pi -e "s/name: 'G9 /name: 'g9 /" "$F/topology-dsl/behavior/recording_conformance.dart"
perl -0pi -e "s/(body: \(RecordingHarness h\) async \{)/\$1\n      const EventTopic<int> trap = EventTopic<int>(name: 'trap.not-a-case');\n      expect(trap.name, 'trap.not-a-case');/" "$F/topology-dsl/behavior/recording_conformance.dart"
echo "  g. an unlisted binding: topic-model behavior/extra_test.dart"
printf "import 'topic_model_conformance.dart';\nvoid main() {}\n" > "$F/topic-model/behavior/extra_test.dart"
echo "  h. an invocation directory with no row: nidana-checks invocation/scan-extra/"
cp -R "$F/nidana-checks/invocation/scan-clean" "$F/nidana-checks/invocation/scan-extra"
echo "  i. a listed data directory renamed: topology-ir render/ to rendr/"
mv "$F/topology-ir/render" "$F/topology-ir/rendr"
echo "  j. a malformed marker: bus-testing reject testing_types_are_closed.dart"
perl -0pi -e 's|// expect-diagnostic: ([a-z_]+)|// expect-diagnostic: Bad_Code|' "$F/bus-testing/reject/testing_types_are_closed.dart"
echo "  k. a not-executable line citing an undeclared id: topic-model G26 to G99"
sed -i '' 's/^- not executable: G26,/- not executable: G99,/' "$C/hsdd/contract/topic-model.md"
echo "  l. a file directly under the slug directory: bus-testing/notes.txt"
touch "$F/bus-testing/notes.txt"
echo "  m. a partial not-executable line without its node clause: topic-model gains one for G4"
perl -pi -e '$_ .= "- not executable: G4\x27s last clause, on a value no case builds\n" if /^- not executable: G25,/' "$C/hsdd/contract/topic-model.md"
grep -n "G4's last clause" "$C/hsdd/contract/topic-model.md" | sed 's/^/  /'
(cd "$C" && fvm dart run "$PROTO"; echo "exit: $?")
grep -c "trap.not-a-case" "$F/topology-dsl/behavior/recording_conformance.dart" | sed 's/^/  trap lines seeded: /'
rm -rf "$C"
