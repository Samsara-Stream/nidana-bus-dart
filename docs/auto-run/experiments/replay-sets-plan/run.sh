#!/usr/bin/env bash
# replay-sets-plan: runtime facts the nidana.model.2 plan depends on and the
# governance does not state (S103).
#   A: what `dart analyze --format=json` prints for fixtures under
#      hsdd/contract/fixture/analysis_options.yaml, given several paths at
#      once, from a temporary workspace (macOS temp paths are symlinked), and
#      for the committed fixtures analyzed by path from the repository root.
#   W: a temporary pub workspace with a stand-in package, resolved offline.
#   X: the dart running a package executable and a test; the working
#      directory a process reads when started through a symbolic link.
#   J: package:json_schema 5.2.2's errors, compile failures and the
#      committed schema sets. P: package_config parsing. O: IOOverrides.
#   M: exact messages of json_schema and dart:convert the tests pin.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
step() { echo; echo "### $*"; }
summ() { (cd "$HERE/probe" && fvm dart run replay_sets_probe:summarize) | sed "s#$REAL#{ws-real}#g; s#$WS#{ws}#g; s#$REPO#{repo}#g"; }
secs() { python3 -c 'import sys,time; print("seconds: %.1f" % (time.time() - float(sys.argv[1])))' "$1"; }
now() { python3 -c 'import time; print(time.time())'; }

step "setup: resolve the probe offline from the pub cache; the dart fvm runs"
(cd probe && fvm dart pub get --offline > /dev/null 2>&1; echo "probe pub get --offline exit: $?")
DART=$(cd probe && fvm dart run replay_sets_probe:exe | sed -n 's/^Platform.resolvedExecutable: //p')
echo "DART = the resolvedExecutable of fvm dart run: ${DART/#$HOME/~}"

T=${TMPDIR:-/tmp}; WS=$(mktemp -d "${T%/}/rsp.XXXXXX")
REAL=$(cd "$WS" && pwd -P)
echo "temp workspace given as {ws}; its symlink-resolved path {ws-real} differs: $([ "$WS" != "$REAL" ] && echo yes || echo no)"
F=hsdd/contract/fixture
mkdir -p "$WS/packages/sample/lib" "$WS/$F/sample/surface" "$WS/$F/sample/reject" "$WS/$F/absent/surface"
cat > "$WS/pubspec.yaml" <<'Y'
name: stand_in_workspace
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/sample
Y
cat > "$WS/packages/sample/pubspec.yaml" <<'Y'
name: sample
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
Y
cat > "$WS/packages/sample/lib/sample.dart" <<'Y'
/// A stand-in package for the replay tool's tests.
library;

sealed class Shape {
  const Shape();
}

final class Circle extends Shape {
  const Circle(this.radius);
  final double radius;
}

final class Square extends Shape {
  const Square(this.side);
  final double side;
}

final class Value {
  const Value(this.n);
  final int n;
}

@Deprecated('use Value')
int old() => 0;
Y
cat > "$WS/packages/sample/lib/broken.dart" <<'Y'
int broken() => 'not an int';
Y
cp "$REPO/$F/analysis_options.yaml" "$WS/$F/analysis_options.yaml"
cat > "$WS/$F/sample/surface/clean.dart" <<'Y'
import 'package:sample/sample.dart';

double radiusOf(Circle c) => c.radius;

int describe(Shape s) => switch (s) {
  Circle() => 1,
  Square() => 2,
};
Y
cat > "$WS/$F/sample/surface/dirty.dart" <<'Y'
import 'dart:async';

import 'package:sample/sample.dart';

int useOld() => old();

List<Object?> inferred() {
  final List list = <int>[];
  return list;
}

void unused() {
  final int x = 1;
}
Y
cat > "$WS/$F/sample/surface/uses_broken.dart" <<'Y'
import 'package:sample/broken.dart';

int twice() => broken() * 2;
Y
cat > "$WS/$F/sample/reject/closed.dart" <<'Y'
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class Triangle extends Shape {}

void f(Value v) {
  // expect-diagnostic: assignment_to_final
  v.n = 2;
}
Y
cat > "$WS/$F/sample/reject/extra_warning.dart" <<'Y'
// covers: G1
import 'package:sample/sample.dart';

void f(Value v) {
  final int unused = 1;
  // expect-diagnostic: assignment_to_final
  v.n = 2;
}
Y
cat > "$WS/$F/absent/surface/pending.dart" <<'Y'
import 'package:absent/absent.dart';
import 'package:sample/sample.dart';

Absent a(Circle c) => Absent(c);
Y

step "W0 fvm dart inside the temp workspace (no .fvmrc above it)"
(cd "$WS" && fvm dart --version 2>&1 | head -2; echo "exit: ${PIPESTATUS[0]}")

step "W1 the temporary workspace resolves offline with DART (no hosted dependency); time"
start=$(now)
(cd "$WS" && "$DART" pub get --offline 2>&1 | sed "s#$REAL#{ws-real}#g; s#$WS#{ws}#g"; echo "exit: ${PIPESTATUS[0]}")
secs "$start"
node -e "const c=require('$WS/.dart_tool/package_config.json'); console.log('package_config packages:', c.packages.map(p=>p.name).join(', '))"
ls "$WS/.dart_tool"

FILES=("$WS/$F/sample/surface/clean.dart" "$WS/$F/sample/surface/dirty.dart" "$WS/$F/sample/surface/uses_broken.dart" "$WS/$F/sample/reject/closed.dart" "$WS/$F/sample/reject/extra_warning.dart" "$WS/$F/absent/surface/pending.dart")

step "A1 one dart analyze --format=json over six files given by absolute path (temp path as given): stdout, exit, time"
start=$(now)
(cd "$WS" && "$DART" analyze --format=json "${FILES[@]}" > "$WS/a1.out" 2> "$WS/a1.err"; echo "exit: $?")
secs "$start"
summ < "$WS/a1.out"
echo "stderr bytes: $(wc -c < "$WS/a1.err" | tr -d ' ')"

step "A1b the same analysis again (a warm second run): time"
start=$(now)
(cd "$WS" && "$DART" analyze --format=json "${FILES[@]}" > /dev/null 2>&1; echo "exit: $?")
secs "$start"

step "A2 the same with --fatal-infos: identical JSON?"
(cd "$WS" && "$DART" analyze --fatal-infos --format=json "${FILES[@]}" > "$WS/a2.out" 2>/dev/null; echo "exit: $?")
cmp -s "$WS/a1.out" "$WS/a2.out" && echo "identical stdout" || { echo "stdout differs:"; diff "$WS/a1.out" "$WS/a2.out" | head -5; }

step "A3 the files by their symlink-resolved paths, run from the repository root: which path does the JSON carry?"
(cd "$REPO" && "$DART" analyze --format=json "$REAL/$F/sample/reject/closed.dart" "$WS/$F/sample/surface/clean.dart" > "$WS/a3.out" 2>/dev/null; echo "exit: $?")
summ < "$WS/a3.out"
echo "raw file fields (home shortened):"; grep -o '"file":"[^"]*"' "$WS/a3.out" | sort -u | sed "s#$HOME#~#g; s#/rsp\.[A-Za-z0-9]*/#/rsp.X/#g"
echo "WS given: $(echo "$WS" | sed "s#/rsp\.[A-Za-z0-9]*#/rsp.X#")"

step "A4 a directory argument and a relative path, run from the temp workspace"
(cd "$WS" && "$DART" analyze --format=json $F/sample/reject > "$WS/a4.out" 2>/dev/null; echo "exit: $?")
summ < "$WS/a4.out"

step "A5 exit codes by worst severity: clean file; warnings only; infos only with and without --fatal-infos"
cat > "$WS/$F/sample/surface/info_only.dart" <<'Y'
import 'package:sample/sample.dart';

int useOld() => old();
Y
cat > "$WS/$F/sample/surface/warning_only.dart" <<'Y'
void unused() {
  final int x = 1;
}
Y
for args in "$F/sample/surface/clean.dart" "$F/sample/surface/warning_only.dart" "$F/sample/surface/info_only.dart" "--fatal-infos $F/sample/surface/info_only.dart" "--fatal-infos $F/sample/surface/clean.dart"; do
  (cd "$WS" && "$DART" analyze --format=json $args > "$WS/a5.out" 2>/dev/null; echo "$args -> exit $? $(head -c 60 "$WS/a5.out" | tr '\n' ' ')")
done

step "A6 a path that does not exist, among existing ones"
(cd "$WS" && "$DART" analyze --format=json $F/sample/surface/clean.dart $F/sample/surface/nosuch.dart > "$WS/a6.out" 2> "$WS/a6.err"; echo "exit: $?")
echo "stdout: $(head -c 300 "$WS/a6.out" | sed "s#$WS#{ws}#g")"
echo "stderr: $(head -c 300 "$WS/a6.err" | sed "s#$WS#{ws}#g")"

step "A7 a fixtures options file with an unknown option: is the options file itself reported?"
cp "$WS/$F/analysis_options.yaml" "$WS/options.bak"
printf 'analyzer:\n  language:\n    strict-casts: true\n    strict-nothing: true\n' > "$WS/$F/analysis_options.yaml"
(cd "$WS" && "$DART" analyze --format=json $F/sample/surface/clean.dart > "$WS/a7.out" 2>/dev/null; echo "exit: $?")
summ < "$WS/a7.out"
cp "$WS/options.bak" "$WS/$F/analysis_options.yaml"

step "A8 the temp workspace with the repository's root options (lints, hsdd/** excluded): same diagnostics as A1?"
cp "$REPO/analysis_options.yaml" "$WS/analysis_options.yaml"
printf 'dev_dependencies:\n  lints: ^6.1.0\n' >> "$WS/pubspec.yaml"
(cd "$WS" && "$DART" pub get --offline > /dev/null 2>&1; echo "pub get --offline with lints exit: $?")
(cd "$WS" && "$DART" analyze --format=json "${FILES[@]}" > "$WS/a8.out" 2>/dev/null; echo "exit: $?")
summ < "$WS/a1.out" > "$WS/a1.sum"; summ < "$WS/a8.out" > "$WS/a8.sum"
cmp -s "$WS/a1.sum" "$WS/a8.sum" && echo "same diagnostics as A1" || diff "$WS/a1.sum" "$WS/a8.sum"

step "A9 the committed fixtures analyzed by path from the repository root (read only; the producers are absent)"
(cd "$REPO" && fvm dart analyze --format=json $F/topic-model/surface/topics.dart $F/topology-ir/reject/ir_holds_no_function.dart > "$WS/a9.out" 2>/dev/null; echo "exit: $?")
summ < "$WS/a9.out" | sed -n '1,12p'

step "A10 time of one analyzer run over every committed surface and reject library, from the repository root"
start=$(now)
(cd "$REPO" && fvm dart analyze --format=json $(ls $F/*/surface/*.dart $F/*/reject/*.dart) > "$WS/a10.out" 2>/dev/null; echo "exit: $?")
secs "$start"
echo "files: $(ls $REPO/$F/*/surface/*.dart $REPO/$F/*/reject/*.dart | wc -l | tr -d ' ')"
summ < "$WS/a10.out" | sed -n '1,2p'

step "A11 the plan's seeds: the stand-in Sample and the reject and surface variants Task 5's tests write"
S2=$WS/seeds
mkdir -p "$S2/packages/sample/lib" "$S2/$F/sample/surface" "$S2/$F/sample/reject"
printf 'name: stand_in_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/sample\n' > "$S2/pubspec.yaml"
printf 'name: sample\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n' > "$S2/packages/sample/pubspec.yaml"
cat > "$S2/packages/sample/lib/sample.dart" <<'Y'
/// The stand-in package the replay tool's tests analyze fixtures against.
library;

/// A class other libraries may construct but never extend.
final class Sample {
  const Sample();

  /// A final field: assigning it reports `assignment_to_final`.
  final int count = 0;
}
Y
cp "$REPO/$F/analysis_options.yaml" "$S2/$F/analysis_options.yaml"
printf "import 'package:sample/sample.dart';\n\nSample use() => Sample();\n" > "$S2/$F/sample/surface/use.dart"
printf "import 'dart:async';\n\nimport 'package:sample/sample.dart';\n\nSample use() => Sample();\n" > "$S2/$F/sample/surface/dirty.dart"
printf "// Reject fixture for sample@v1 G1: the sample type is closed.\n// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: invalid_use_of_type_outside_library\nfinal class Local extends Sample {}\n" > "$S2/$F/sample/reject/sample_is_closed.dart"
printf "// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: invalid_use_of_type_outside_library\nconst int before = 0;\nfinal class Local extends Sample {}\n" > "$S2/$F/sample/reject/wrong_line.dart"
printf "// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: undefined_class\nfinal class Local extends Sample {}\n" > "$S2/$F/sample/reject/wrong_code.dart"
printf "// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: invalid_use_of_type_outside_library\nfinal class Local extends Sample {}\n\nvoid f() {\n  final int unused = 0;\n}\n" > "$S2/$F/sample/reject/extra_warning.dart"
printf "// covers: G1\nimport 'package:sample/sample.dart';\n\nvoid f(Sample s) {\n  // expect-diagnostic: assignment_to_final\n  s.count = 1;\n}\n" > "$S2/$F/sample/reject/assigns_final.dart"
(cd "$S2" && "$DART" pub get --offline > /dev/null 2>&1; echo "pub get --offline exit: $?")
(cd "$S2" && "$DART" analyze --format=json $F/sample/surface/use.dart $F/sample/surface/dirty.dart $F/sample/reject/*.dart > "$WS/a11.out" 2>/dev/null; echo "exit: $?")
summ < "$WS/a11.out" | sed "s#{ws-real}/seeds/##"

step "A12 the repository's bin script run from a temporary workspace that has its own package configuration (the tests' setup)"
(cd "$S2" && "$DART" "$REPO/packages/nidana_contract_check/bin/nidana_contract_check.dart" --all --set structure 2>&1 | sed "s#$REAL#{ws-real}#g; s#$WS#{ws}#g"; echo "exit: ${PIPESTATUS[0]}")

step "X1 the dart running a package executable (fvm dart run) and a test (fvm dart test)"
(cd probe && fvm dart run replay_sets_probe:exe | sed "s#$HOME#~#g")
(cd probe && fvm dart test test/exe_test.dart 2>&1 | grep -E 'resolvedExecutable|All tests' | sed "s#$HOME#~#g")

step "X2 a process started with a symbolic link as its working directory: what Directory.current reads"
LN=$(mktemp -d "${T%/}/rsplink.XXXXXX"); ln -s "$S2" "$LN/linked"
(cd "$LN/linked" && "$DART" "$HERE/probe/bin/exe.dart" | grep Directory.current | sed "s#$REAL#{ws-real}#g; s#$LN#{link-dir}#g; s#$WS#{ws}#g")
echo "the link itself: {link-dir}/linked -> {ws-real}/seeds or {ws}/seeds"
rm -rf "$LN"

step "J json_schema 5.2.2"
(cd "$REPO" && fvm dart run "$HERE/probe/bin/schema_probe.dart" 2>&1 | sed "s#$REPO#{repo}#g")

step "M exact messages the plan's tests pin"
(cd probe && fvm dart run replay_sets_probe:message_probe)

step "P package_config 2.2.0 on the temp workspace's configuration"
(cd probe && fvm dart run replay_sets_probe:config_probe "$WS/.dart_tool/package_config.json" | sed "s#$WS#{ws}#g")

step "O IOOverrides and matcher's fail"
(cd probe && fvm dart run replay_sets_probe:override_probe "$WS" | sed "s#$WS#{ws}#g; s#$HERE#{here}#g")

step "cleanup"
rm -rf "$WS" probe/.dart_tool; echo "removed the temp workspace and probe/.dart_tool (probe/pubspec.lock kept)"
