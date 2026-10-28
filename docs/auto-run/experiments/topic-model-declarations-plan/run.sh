#!/usr/bin/env bash
# topic-model-declarations-plan: runtime facts the nidana.model.3 plan depends
# on (S106). It replays the plan's task sequence in a temporary copy of the
# committed tree (git archive HEAD), with the files drafted under draft/, and
# records what each task's failing step and passing step print:
#   S: the committed tree, before the package exists.
#   T1: the purity test alone, then the package scaffold and the workspace
#       entry (the lockfile, the replay with an empty main library), and
#       seeded violations the purity test must catch.
#   T2: the topic and scope declarations: the declarations test fails to
#       compile first, then the replay passes the fixtures they serve.
#   T3: the rest of the Interface: the whole replay passes.
#   G: the phase gate, as the phase context writes it.
#   R: every (line, code) pair reported in each reject library, and whether
#      any line carries two codes (the routed ADR-001 item 4 question).
#   B: topic-model@v1's behavior binding against the declarations: it loads,
#      and its cases fail on UnimplementedError (a fact for nidana.model.6).
# draft/ is evidence, not code to copy; the plan states the declarations.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/tmdp.XXXXXX")
P=$WS/packages/nidana_dart_contracts
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-220; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check topic-model --set structure,surface,reject > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "PASS structure lines: $(grep -c '^PASS structure' "$WS/replay.out")"
  grep -v '^PASS structure' "$WS/replay.out" | clip
}
tests() { (cd "$WS" && fvm dart test "$@" 2>&1 | grep -E '^\s*[0-9]+:[0-9]+ \+|Error|error|Expected|Actual|reason|Which' | tail -n 14 | clip; echo "exit: ${PIPESTATUS[0]}"); }
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 6 | clip; echo "exit: ${PIPESTATUS[0]}"); }

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
cp "$WS/pubspec.lock" "$WS/pubspec.lock.orig"
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)

step "S1 the replay before the package exists"
replay

step "T1.2 the purity test alone, before the package has a pubspec"
mkdir -p "$P/test"
cp "$DRAFT/test/purity_test.dart" "$P/test/"
tests packages/nidana_dart_contracts

step "T1.3 the scaffold: pubspec, README, CHANGELOG, LICENSE, an empty main library, the workspace entry"
mkdir -p "$P/lib"
cp "$DRAFT/pubspec.yaml" "$DRAFT/README.md" "$DRAFT/CHANGELOG.md" "$P/"
cp "$WS/LICENSE" "$P/LICENSE"
cp "$DRAFT/lib/nidana_dart_contracts.stage1.dart" "$P/lib/nidana_dart_contracts.dart"
perl -0pi -e 's#  - packages/nidana_contract_check\n#  - packages/nidana_contract_check\n  - packages/nidana_dart_contracts\n#' "$WS/pubspec.yaml"
cat "$WS/pubspec.yaml"
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
if cmp -s "$WS/pubspec.lock" "$WS/pubspec.lock.orig"; then echo "pubspec.lock: unchanged"; else echo "pubspec.lock: changed"; diff "$WS/pubspec.lock.orig" "$WS/pubspec.lock"; fi
cmp -s "$P/LICENSE" "$REPO/LICENSE" && echo "LICENSE: byte-identical to the root's"

step "T1.4 the purity test, the analyzer and the replay with an empty main library"
tests packages/nidana_dart_contracts
analyze
replay

step "T1.5 seeded violations the purity test catches (each restored after)"
cp "$P/lib/nidana_dart_contracts.dart" "$WS/main.bak"
printf "\nimport 'dart:io' as io;\n" >> "$P/lib/nidana_dart_contracts.dart"
echo "-- an aliased dart:io import"; tests packages/nidana_dart_contracts/test/purity_test.dart
cp "$WS/main.bak" "$P/lib/nidana_dart_contracts.dart"
printf "\n// Timer( in a comment still counts\n" >> "$P/lib/nidana_dart_contracts.dart"
echo "-- Timer( in a comment"; tests packages/nidana_dart_contracts/test/purity_test.dart
cp "$WS/main.bak" "$P/lib/nidana_dart_contracts.dart"
cp "$P/pubspec.yaml" "$WS/pubspec.bak"
perl -0pi -e 's#  meta: \^1.19.0\n#  meta: ^1.19.0\n  path: ^1.9.1\n#' "$P/pubspec.yaml"
echo "-- path as a second dependency"; tests packages/nidana_dart_contracts/test/purity_test.dart
cp "$WS/pubspec.bak" "$P/pubspec.yaml"

step "T2.2 the declarations test for topics, before topic.dart and scope.dart exist"
cp "$DRAFT/test/declarations_test.stage2.dart" "$P/test/declarations_test.dart"
tests packages/nidana_dart_contracts/test/declarations_test.dart

step "T2.4 topic.dart, scope.dart and their exports"
mkdir -p "$P/lib/src/topic"
cp "$DRAFT/lib/src/topic/topic.dart" "$DRAFT/lib/src/topic/scope.dart" "$P/lib/src/topic/"
cp "$DRAFT/lib/nidana_dart_contracts.stage2.dart" "$P/lib/nidana_dart_contracts.dart"
tests packages/nidana_dart_contracts
analyze
replay

step "T3.2 the declarations test for the rest, before its declarations exist"
cp "$DRAFT/test/declarations_test.dart" "$P/test/declarations_test.dart"
tests packages/nidana_dart_contracts/test/declarations_test.dart

step "T3.4 message_source.dart, envelope.dart, lineage.dart, redacted_payload.dart, observer.dart and their exports"
cp "$DRAFT/lib/src/topic/"*.dart "$P/lib/src/topic/"
cp "$DRAFT/lib/nidana_dart_contracts.dart" "$P/lib/nidana_dart_contracts.dart"
tests packages/nidana_dart_contracts
analyze
replay
(cd "$WS" && fvm dart format --output=none --set-exit-if-changed packages/nidana_dart_contracts 2>&1 | tail -n 1; echo "format exit: ${PIPESTATUS[0]}")

step "G the phase gate, from the workspace root"
(cd "$WS" && bash -c 'fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model --set structure,surface,reject' > "$WS/gate.out" 2>&1; echo "gate exit: $?")
grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed' "$WS/gate.out" | clip

step "R every (line, code) pair reported in each reject library; a line with two codes is flagged"
(cd "$WS" && fvm dart analyze --format=json hsdd/contract/fixture/topic-model/reject 2>/dev/null) | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    const by = {};
    for (const d of JSON.parse(s).diagnostics) {
      const f = d.location.file.split("/").pop();
      (by[f] = by[f] || []).push([d.location.range.start.line, d.code]);
    }
    for (const f of Object.keys(by).sort()) {
      const lines = {};
      for (const [l, c] of by[f]) (lines[l] = lines[l] || new Set()).add(c);
      const two = Object.keys(lines).filter(l => lines[l].size > 1);
      console.log(f, by[f].map(([l, c]) => l + ":" + c).join(" "), two.length ? "TWO CODES ON " + two.join(",") : "one code per line");
    }
  });'

step "B topic-model@v1's behavior binding against the declarations (not in this gate)"
(cd "$WS" && fvm dart analyze --fatal-infos hsdd/contract/fixture/topic-model/behavior 2>&1 | tail -n 1)
(cd "$WS" && fvm dart test hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart > "$WS/behavior.out" 2>&1; echo "exit: $?")
grep -E '^\s*[0-9]+:[0-9]+ \+[0-9]+.*(Some tests failed|All tests passed)' "$WS/behavior.out" | tail -n 1
echo "UnimplementedError mentions: $(grep -c UnimplementedError "$WS/behavior.out")"

step "cleanup"
rm -rf "$WS"; echo "removed the temporary workspace"
