#!/usr/bin/env bash
# sweep-adr-001: evidence for S155, the end-of-nidana.model governance sweep
# of ADR-001 (hsdd-adr, an amendment in place). It reads the shipped replay
# tool's behavior for each reading the amendment states, in a temporary copy
# of the committed tree (git archive HEAD), so packages/ is the shipped tool:
#   L: checks.py over the committed hsdd/contract/ (read only): every
#      conformance library bound, no configured directive, no case named in
#      two Case rows, every plugins line exact, every file replay and recorded
#      invocation declaring ids, no recorded invocation running dart run.
#   S0: the copy, with seed/ added: a stand-in member probe_tool (three
#      executables) and three probe slugs, probe-cli (kind cli), probe-file
#      (kind file) and probe-api (kind shared-model, behavior only).
#   A: --set structure over the probe slugs: what structure does not check.
#   B: the behavior set, unrestricted and restricted: a binding that imports
#      no conformance library or two, a configured URI naming an absent
#      package, PENDING against the restriction.
#   C: the cli set, unrestricted and restricted: the {package}:{executable}
#      form, files/ written by a command, a plugins line with a comment, a
#      case named in two rows, a defect and an absent package against the
#      restriction.
#   D: the file set: the generator span, a file replay that declares no id.
#   E: a stale workspace: the cli set's form against dart run from files/,
#      and what dart pub get --enforce-lockfile does to the modification
#      times.
#   F: dart analyze . from a plugin case's files/, its plugins section
#      removed: whether it writes below files/.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/sweepadr.XXXXXX")
WSR=$(cd "$WS" && pwd -P)
step() { echo; echo "### $*"; }
clip() { sed "s#$WSR#{ws}#g; s#$WS#{ws}#g" | cut -c1-260; } # the resolved path, the longer, first
replay() { # replay <args...>: the tool's stdout and exit, stderr's ERROR lines
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2> "$WS/replay.err"; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  grep -v '^PASS structure hsdd/contract/fixture/[a-z-]*/behavior/\|^PASS structure hsdd/contract/fixture/[a-z-]*/$' "$WS/replay.out" | clip
  grep '^ERROR' "$WS/replay.err" | clip
}
mtimes() {
  (cd "$WS" && for f in pubspec.yaml packages/probe_tool/pubspec.yaml pubspec.lock .dart_tool/package_config.json; do
    printf '%s=%s ' "$f" "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")"
  done; echo)
}

step "S0 setup: the committed tree"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
echo "packages/ changes in the working tree: $(git -C "$REPO" status --porcelain packages | wc -l | tr -d ' ')"
fvm dart --version 2>&1

step "L checks.py over the committed hsdd/contract/"
python3 -I "$HERE/checks.py" "$WS"

step "S0 the probes added: probe_tool in the workspace, the probe slugs, resolved offline"
cp -R "$HERE/seed/." "$WS/"
python3 -I - "$WS/pubspec.yaml" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1])
t = f.read_text()
a = '  - packages/nidana_dart_contracts\n'
assert t.count(a) == 1
f.write_text(t.replace(a, a + '  - packages/probe_tool\n'))
PY
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)

step "A structure over the probe slugs"
replay probe-cli probe-file probe-api --set structure

step "B the behavior set, unrestricted"
replay probe-api --set behavior
step "B the behavior set, restricted to G1"
replay probe-api --set behavior --guarantee G1

step "C the cli set, unrestricted"
replay probe-cli --set cli
echo "-- below facts/files/ after the run:"
(cd "$WS/hsdd/contract/fixture/probe-cli/invocation/facts/files" && find . -type f | sort && cat left.txt 2>/dev/null)
step "C the cli set, restricted to G5 (the second row of dup)"
replay probe-cli --set cli --guarantee G5
step "C the cli set, restricted to G4 (the first row of dup)"
replay probe-cli --set cli --guarantee G4

step "D the file set, unrestricted"
replay probe-file --set file
step "D the file set, restricted to G1"
replay probe-file --set file --guarantee G1

step "E a stale workspace: a member pubspec.yaml newer than pubspec.lock"
mtimes
sleep 2
touch "$WS/packages/probe_tool/pubspec.yaml"
mtimes
replay probe-cli --set cli --guarantee G1
echo "-- after the replay's dart pub get --enforce-lockfile:"
mtimes
(cd "$WS" && fvm dart pub get --enforce-lockfile --offline 2>&1 | tail -n 1)
echo "-- after one more dart pub get --enforce-lockfile --offline:"
mtimes
F=$WS/hsdd/contract/fixture/probe-cli/invocation/facts/files
(cd "$F" && fvm dart run probe_tool:facts > "$WS/run.out" 2>&1; echo "dart run probe_tool:facts from facts/files/: exit $?"; head -n 2 "$WS/run.out" | clip)
(cd "$F" && fvm dart --packages="$WS/.dart_tool/package_config.json" "$WS/packages/probe_tool/bin/facts.dart" > "$WS/run.out" 2>&1; echo "dart --packages=... bin/facts.dart from facts/files/: exit $?"; head -n 3 "$WS/run.out" | clip)

step "F dart analyze . from analyze-clean's files/, its plugins section removed"
A=$WS/hsdd/contract/fixture/nidana-checks/invocation/analyze-clean/files
python3 -I - "$A/analysis_options.yaml" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1])
t = f.read_text()
f.write_text(t[:t.index('plugins:')])
PY
(cd "$A" && find . | sort) > "$WS/before.txt"
(cd "$A" && fvm dart analyze . > "$WS/analyze.out" 2>&1; echo "dart analyze .: exit $?"; tail -n 1 "$WS/analyze.out" | clip)
(cd "$A" && find . | sort) > "$WS/after.txt"
echo "entries below files/ before: $(wc -l < "$WS/before.txt" | tr -d ' '), after: $(wc -l < "$WS/after.txt" | tr -d ' ')"
diff "$WS/before.txt" "$WS/after.txt" && echo "no entry added or removed"

rm -rf "$WS"
