#!/usr/bin/env bash
# file-cli-sets-plan, staleness part 3: ways to run `{package}:{executable}`
# from files/ that do not depend on the mtimes pub reads, on a workspace whose
# mtimes read stale (a member pubspec.yaml newer than pubspec.lock):
#   N1 dart run gen:generate (the reference: exit 255)
#   N2 dart {root}/packages/gen/bin/generate.dart
#   N3 dart run {root}/packages/gen/bin/generate.dart
#   N4 dart --packages={root}/.dart_tool/package_config.json {script}
#   N5 N4's form for a script that imports another library of its package
#      (package:gen/...), the case a real generator is
#   N6 N4's form when the package's bin/{executable}.dart does not exist
#   N7 N4's form on a fresh workspace, from the root: same output as dart run
#   N8 the time of N4 against dart run, from the root, five runs each
# Run from anywhere: ./staleness3.sh > staleness3-output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}; T=${T%/}
TREAL=$(cd "$T" && pwd -P)
DART=$(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-cli-sets-plan/probe/paths.dart exe)
step() { echo; echo "### $*"; }
red() { sed -e "s#$TREAL#{T-real}#g" -e "s#$T#{T}#g" -e "s#$HOME#~#g"; }
now() { python3 -c 'import time; print(time.time())'; }
W=$(mktemp -d "$T/fcs.XXXXXX")
C=hsdd/contract/fixture/sample/invocation/case/files
mkdir -p "$W/packages/gen/bin" "$W/packages/gen/lib" "$W/$C"
printf 'name: stand_in_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/gen\n' > "$W/pubspec.yaml"
printf 'name: gen\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n' > "$W/packages/gen/pubspec.yaml"
cp probe/generate.dart "$W/packages/gen/bin/generate.dart"
printf "String greeting() => 'from lib';\n" > "$W/packages/gen/lib/gen.dart"
printf "import 'package:gen/gen.dart';\n\nvoid main() => print(greeting());\n" > "$W/packages/gen/bin/greet.dart"
printf 'hello\n' > "$W/$C/in.txt"
(cd "$W" && "$DART" pub get --offline > /dev/null 2>&1)
sleep 2; touch "$W/packages/gen/pubspec.yaml"
S="$W/packages/gen/bin/generate.dart"
P="--packages=$W/.dart_tool/package_config.json"
try() { local label=$1; shift; (cd "$W/$C" && "$@" > "$W/o" 2> "$W/e"; echo "$label: exit $?"); red < "$W/o" | sed 's/^/  | /'; red < "$W/e" | head -2 | sed 's/^/  ! /'; rm -rf "$W/out"; }

step "N1 dart run gen:generate from files/ (stale)"
try N1 "$DART" run gen:generate in.txt "$W/out"
step "N2 dart {script} from files/ (stale)"
try N2 "$DART" "$S" in.txt "$W/out"
step "N3 dart run {script} from files/ (stale)"
try N3 "$DART" run "$S" in.txt "$W/out"
step "N4 dart --packages={config} {script} from files/ (stale)"
try N4 "$DART" "$P" "$S" in.txt "$W/out"
step "N5 N4's form for a script that imports package:gen/gen.dart (stale)"
try N5 "$DART" "$P" "$W/packages/gen/bin/greet.dart"
try "N5, dart run gen:greet" "$DART" run gen:greet
step "N6 N4's form for an executable the package does not have"
try N6 "$DART" "$P" "$W/packages/gen/bin/nosuch.dart"
step "N7 a fresh workspace, from the root: N4 and dart run print the same"
sleep 2; touch "$W/pubspec.lock"; sleep 2; touch "$W/.dart_tool/package_config.json"
(cd "$W" && "$DART" run gen:generate "$C/in.txt" "$W/out" > "$W/a" 2>&1; echo "dart run: exit $?"); rm -rf "$W/out"
(cd "$W" && "$DART" "$P" "$S" "$C/in.txt" "$W/out" > "$W/b" 2>&1; echo "N4: exit $?"); rm -rf "$W/out"
cmp -s "$W/a" "$W/b" && echo "the two outputs are EQUAL"
step "N8 the time of five runs each, from the root"
t0=$(now); for i in 1 2 3 4 5; do (cd "$W" && "$DART" run gen:generate "$C/in.txt" "$W/out" > /dev/null 2>&1); rm -rf "$W/out"; done
python3 -c 'import sys,time; print("dart run, five runs: %.1f s" % (time.time() - float(sys.argv[1])))' "$t0"
t0=$(now); for i in 1 2 3 4 5; do (cd "$W" && "$DART" "$P" "$S" "$C/in.txt" "$W/out" > /dev/null 2>&1); rm -rf "$W/out"; done
python3 -c 'import sys,time; print("N4, five runs: %.1f s" % (time.time() - float(sys.argv[1])))' "$t0"
rm -rf "$W"
