#!/usr/bin/env bash
# file-cli-sets-plan: runtime facts the nidana.model.7 plan (S121) depends on
# and the governance does not state.
#   D: the dart that runs the tool, and what `fvm dart` does where no .fvmrc
#      is above the working directory (a temporary workspace).
#   S: macOS temporary paths (/var and /private/var): how a temporary
#      directory's path reads, what a child started there reads and prints,
#      and the order in which a given and a resolved path must be replaced.
#   A: what `dart analyze --format=machine .` prints for a file below a
#      temporary working directory: the given or the resolved path.
#   I: whether a child that reads stdin under Process.run gets an end of input.
#   F: `dart format` over a directory: which files it formats, its output and
#      exit codes (formatted, unchanged, empty, absent, a file that does not
#      parse), and the language version it uses outside any package.
#   W: a temporary pub workspace with a stand-in generator member `gen` (no
#      hosted dependency), resolved offline.
#   P: `dart pub get --enforce-lockfile` there: on success, with no network,
#      on a lockfile that lacks a dependency, without a lockfile.
#   G: `dart run gen:generate` there: from the root and from a directory below
#      it with no pubspec.yaml (a recorded invocation's files/), on its first
#      and later runs (what reaches stdout), on a stale resolution, for a
#      package the workspace lacks, and for an executable that does not
#      compile.
# No flutter command is run. Every temporary path is printed as {T} (as
# given) or {T-real} (symlink-resolved), the home directory as ~.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}; T=${T%/}
TREAL=$(cd "$T" && pwd -P)
step() { echo; echo "### $*"; }
red() { sed -e "s#$TREAL#{T-real}#g" -e "s#$T#{T}#g" -e "s#$HOME#~#g"; }
now() { python3 -c 'import time; print(time.time())'; }
secs() { python3 -c 'import sys,time; print("seconds: %.1f" % (time.time() - float(sys.argv[1])))' "$1"; }
run() { # run <label> <command...>: stdout, stderr and exit, redacted
  local o e c
  o=$(mktemp); e=$(mktemp)
  "${@:2}" > "$o" 2> "$e"; c=$?
  echo "-- $1"; echo "stdout:"; red < "$o" | sed 's/^/  | /'; echo "stderr:"; red < "$e" | sed 's/^/  | /'; echo "exit: $c"
  rm -f "$o" "$e"
}

step "D1 the dart that runs a program under fvm dart run, from the repository"
DART=$(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-cli-sets-plan/probe/paths.dart exe)
echo "Platform.resolvedExecutable: ${DART/#$HOME/~}"
"$DART" --version 2>&1

step "D2 fvm dart from a temporary directory (no .fvmrc above it)"
D2=$(mktemp -d "$T/fcs.XXXXXX")
run "fvm dart --version in {T}" sh -c "cd '$D2' && fvm dart --version"
rmdir "$D2"

step "S1 a temporary directory's path as Dart reads it"
"$DART" probe/paths.dart temp | red

step "S2 a child started with a temporary working directory, given {output} as an argument; then both replacement orders"
"$DART" probe/paths.dart spawn | red

step "I1 a child that reads stdin under Process.run"
"$DART" probe/paths.dart stdin-parent

step "F1 dart format over a directory: which files it formats"
F=$(mktemp -d "$T/fcs.XXXXXX")
mkdir -p "$F/fmt/sub" "$F/fmt/.hidden"
for p in a.dart sub/b.dart .hidden/c.dart .d.dart x.txt e.dart.txt; do
  printf 'void  main( ){print( 1 );}\n' > "$F/fmt/$p"
done
cp -R "$F/fmt" "$F/orig"
run "dart format {dir}" "$DART" format "$F/fmt"
for p in a.dart sub/b.dart .hidden/c.dart .d.dart x.txt e.dart.txt; do
  if cmp -s "$F/fmt/$p" "$F/orig/$p"; then echo "$p: unchanged"; else echo "$p: formatted"; fi
done
run "dart format {dir} again (nothing to change)" "$DART" format "$F/fmt"

step "F2 dart format over an empty directory, and over a path that does not exist"
mkdir "$F/empty"
run "empty directory" "$DART" format "$F/empty"
run "absent path" "$DART" format "$F/nope"

step "F3 dart format over a directory holding a file that does not parse"
mkdir "$F/bad"
printf 'void  main( ){print( 1 );}\n' > "$F/bad/good.dart"
printf 'void main( {\n' > "$F/bad/bad.dart"
run "good.dart and bad.dart" "$DART" format "$F/bad"
if cmp -s "$F/bad/good.dart" "$F/orig/a.dart"; then echo "good.dart: unchanged"; else echo "good.dart: formatted"; fi

step "F4 the language version outside any package: topic-codegen's expected/topics.g.dart, and a sample whose short and tall styles differ"
mkdir "$F/tall"
cp "$REPO/hsdd/contract/fixture/topic-codegen/expected/topics.g.dart" "$F/tall/"
run "topics.g.dart in {T}" "$DART" format "$F/tall"
cmp -s "$F/tall/topics.g.dart" "$REPO/hsdd/contract/fixture/topic-codegen/expected/topics.g.dart" && echo "topics.g.dart: no byte changed"
SAMPLE='void f() { someFunction(argumentNumberOne, argumentNumberTwo, argumentNumberThree, argumentFour); }'
mkdir -p "$F/style" "$HERE/work-style"
printf '%s\n' "$SAMPLE" > "$F/style/s.dart"
printf '%s\n' "$SAMPLE" > "$HERE/work-style/s.dart"
"$DART" format "$F/style" > /dev/null 2>&1
(cd "$REPO" && "$DART" format "$HERE/work-style" > /dev/null 2>&1)
echo "outside any package:"; sed 's/^/  | /' "$F/style/s.dart"
echo "below the repository root (language 3.13):"; sed 's/^/  | /' "$HERE/work-style/s.dart"
cmp -s "$F/style/s.dart" "$HERE/work-style/s.dart" && echo "the two are EQUAL"
mkdir -p "$F/short/lib"
printf 'name: short\nenvironment:\n  sdk: ^3.6.0\n' > "$F/short/pubspec.yaml"
printf '%s\n' "$SAMPLE" > "$F/short/lib/s.dart"
(cd "$F/short" && "$DART" pub get --offline > /dev/null 2>&1; echo "short: pub get exit $?")
"$DART" format "$F/short/lib" > /dev/null 2>&1
echo "in a package at language 3.6 (short style):"; sed 's/^/  | /' "$F/short/lib/s.dart"
rm -rf "$F" "$HERE/work-style"

step "W1 a temporary workspace with a stand-in generator member gen, resolved offline"
W=$(mktemp -d "$T/fcs.XXXXXX")
C=hsdd/contract/fixture/sample/invocation/case/files
mkdir -p "$W/packages/gen/bin" "$W/$C"
printf 'name: stand_in_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/gen\n' > "$W/pubspec.yaml"
printf 'name: gen\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n' > "$W/packages/gen/pubspec.yaml"
cp probe/generate.dart "$W/packages/gen/bin/generate.dart"
printf 'hello\n' > "$W/$C/in.txt"
printf 'hello\n' > "$W/in.txt"
t0=$(now)
run "pub get --offline" sh -c "cd '$W' && '$DART' pub get --offline"
secs "$t0"
ls "$W" | tr '\n' ' '; echo

step "P1 dart pub get --enforce-lockfile at its root"
run "enforce-lockfile" sh -c "cd '$W' && '$DART' pub get --enforce-lockfile"

step "P2 the same with every proxy pointing at a closed port (no network)"
run "enforce-lockfile, no network" sh -c "cd '$W' && HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 '$DART' pub get --enforce-lockfile"

step "P3 a member pubspec.yaml that adds a dependency the lockfile lacks"
cp "$W/packages/gen/pubspec.yaml" "$W/gen-pubspec.orig"
printf 'dependencies:\n  path: ^1.9.1\n' >> "$W/packages/gen/pubspec.yaml"
run "enforce-lockfile on a stale lockfile" sh -c "cd '$W' && '$DART' pub get --enforce-lockfile"
cp -p "$W/gen-pubspec.orig" "$W/packages/gen/pubspec.yaml"; rm "$W/gen-pubspec.orig"
run "restored" sh -c "cd '$W' && '$DART' pub get --enforce-lockfile"

step "P4 no lockfile"
mv "$W/pubspec.lock" "$W/pubspec.lock.orig"
run "enforce-lockfile without pubspec.lock" sh -c "cd '$W' && '$DART' pub get --enforce-lockfile"
mv "$W/pubspec.lock.orig" "$W/pubspec.lock"
ls "$W" | tr '\n' ' '; echo

step "G1 dart run gen:generate from the root, first run (nothing compiled yet): stdout as bytes"
rm -rf "$W/.dart_tool/pub/bin"
t0=$(now)
(cd "$W" && "$DART" run gen:generate in.txt "$W/out1" > "$W/g1.out" 2> "$W/g1.err"; echo "exit: $?")
secs "$t0"
echo "stdout:"; red < "$W/g1.out" | sed 's/^/  | /'
echo "stderr:"; red < "$W/g1.err" | sed 's/^/  | /'
echo "first stdout bytes:"; head -c 24 "$W/g1.out" | od -c | head -2 | red

step "G2 a second run from the root"
t0=$(now)
run "second run" sh -c "cd '$W' && '$DART' run gen:generate in.txt '$W/out2'"
secs "$t0"

step "G3 from a directory below the root with no pubspec.yaml (a recorded invocation's files/)"
t0=$(now)
run "from files/" sh -c "cd '$W/$C' && '$DART' run gen:generate in.txt '$W/out3'"
secs "$t0"

step "G4 a stale resolution: the root pubspec.yaml touched after it"
sleep 1; touch "$W/pubspec.yaml"
run "from files/, stale" sh -c "cd '$W/$C' && '$DART' run gen:generate in.txt '$W/out4'"
run "pub get --enforce-lockfile at the root" sh -c "cd '$W' && '$DART' pub get --enforce-lockfile"
run "from files/, after it" sh -c "cd '$W/$C' && '$DART' run gen:generate in.txt '$W/out5'"
sleep 1; touch "$W/pubspec.yaml"
run "from the root, stale" sh -c "cd '$W' && '$DART' run gen:generate in.txt '$W/out6'"

step "G5 a package the workspace lacks"
run "dart run nosuch:generate" sh -c "cd '$W' && '$DART' run nosuch:generate in.txt '$W/out7'"
echo "out7 exists: $([ -e "$W/out7" ] && echo yes || echo no)"

step "G6 an executable that does not compile"
printf 'void main() { undefinedName(); }\n' > "$W/packages/gen/bin/broken.dart"
run "dart run gen:broken" sh -c "cd '$W' && '$DART' run gen:broken"

step "A1 dart analyze --format=machine . from a temporary files/ directory"
printf 'name: example_app\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\n' > "$W/$C/pubspec.yaml"
mkdir -p "$W/$C/lib"
printf "import 'dart:async';\n\nvoid f() {}\n" > "$W/$C/lib/a.dart"
run "machine format" sh -c "cd '$W/$C' && '$DART' analyze --format=machine ."
run "default format" sh -c "cd '$W/$C' && '$DART' analyze ."
rm -rf "$W"
