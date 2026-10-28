#!/usr/bin/env bash
# sweep-topic-model: evidence for S151, the end-of-nidana.model governance
# sweep of topic-model@v1 (hsdd-contract, compatible touch within v1). It
# works in a temporary copy of the committed tree (git archive HEAD), so
# packages/ is the shipped package, and records:
#   F: facts/facts.dart against the shipped package, run from the repository
#      root (short renderings, redacting twice, Lineage.combine, redactions of
#      1 and 1.0, a NaN payload against Dart's collections and records, the
#      renderings of Topic, TopicRef and Lineage).
#   L: lint/angle_brackets.dart (the contract's doc comment before S151) and
#      lint/backticks.dart (as S151 writes it, the package's text) under the
#      root analysis options, inside the package.
#   B: the committed fixtures, replayed unrestricted.
#   N: the fixtures with S151's three cases (the working tree's conformance
#      library), replayed unrestricted.
#   D: seeded defects in the copy's package, each restored after, replayed
#      restricted to the guarantee they touch, with the committed cases and
#      with S151's: D1 an identity shortcut in MessageEnvelope ==, D2 redaction
#      that keeps a payload that is already a RedactedPayload, D3 RedactedPayload
#      == comparing the hash alone.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/sweeptm.XXXXXX")
P=$WS/packages/nidana_dart_contracts
CONF=hsdd/contract/fixture/topic-model/behavior/topic_model_conformance.dart
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-300; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  grep -E '^(PASS|FAIL) behavior|fixtures:|^exit:' "$WS/replay.out" | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
seed() { # seed <file under lib/src/topic> <perl substitution>
  cp "$P/lib/src/topic/$1" "$WS/seed.bak"
  perl -0pi -e "$2" "$P/lib/src/topic/$1"
  echo "-- seeded diff:"; diff "$WS/seed.bak" "$P/lib/src/topic/$1" | clip
}
unseed() { cp "$WS/seed.bak" "$P/lib/src/topic/$1"; }

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)

step "F facts/facts.dart against the shipped package (packages/ is unchanged in the working tree)"
echo "packages/ changes in the working tree: $(git -C "$REPO" status --porcelain packages | wc -l | tr -d ' ')"
(cd "$REPO" && fvm dart run "$HERE/facts/facts.dart" 2>&1)

step "L the Message sources doc comment under the root analysis options"
for f in angle_brackets backticks; do
  cp "$HERE/lint/$f.dart" "$P/lib/src/probe_$f.dart"
  echo "-- $f.dart"
  (cd "$WS" && fvm dart analyze --fatal-infos "packages/nidana_dart_contracts/lib/src/probe_$f.dart" 2>&1 | grep -E ' - |No issues' | clip)
  rm "$P/lib/src/probe_$f.dart"
done

step "B the committed fixtures, unrestricted"
replay topic-model

step "N S151's conformance library (three new cases), unrestricted"
cp "$WS/$CONF" "$WS/conf.committed"
cp "$REPO/$CONF" "$WS/$CONF"
echo "-- cases added:"; diff "$WS/conf.committed" "$WS/$CONF" | grep -E "^> +name: " | sed 's/^> *//'
replay topic-model

step "D1 identity shortcut in MessageEnvelope =="
seed envelope.dart 's/other is MessageEnvelope<Object\?> &&\n/identical(this, other) ||\n      other is MessageEnvelope<Object?> &&\n/'
echo "- committed cases:"; cp "$WS/conf.committed" "$WS/$CONF"; replay topic-model --guarantee G13
echo "- with S151's cases:"; cp "$REPO/$CONF" "$WS/$CONF"; replay topic-model --guarantee G13
unseed envelope.dart

step "D2 redaction keeps a payload that is already a RedactedPayload"
seed envelope.dart 's/payload: RedactedPayload\.of\(payload\),/payload: payload is RedactedPayload ? payload : RedactedPayload.of(payload),/; s/\$\{sensitive \? RedactedPayload\.of\(payload\) : payload\}/\${sensitive \&\& payload is! RedactedPayload ? RedactedPayload.of(payload) : payload}/'
echo "- committed cases:"; cp "$WS/conf.committed" "$WS/$CONF"; replay topic-model --guarantee G15
echo "- with S151's cases:"; cp "$REPO/$CONF" "$WS/$CONF"; replay topic-model --guarantee G15
unseed envelope.dart

step "D3 RedactedPayload == compares the hash alone"
seed redacted_payload.dart 's/other is RedactedPayload &&\n      other\.typeName == typeName &&\n      other\.hash == hash;/other is RedactedPayload \&\& other.hash == hash;/'
echo "- committed cases:"; cp "$WS/conf.committed" "$WS/$CONF"; replay topic-model --guarantee G24
echo "- with S151's cases:"; cp "$REPO/$CONF" "$WS/$CONF"; replay topic-model --guarantee G24
unseed redacted_payload.dart

step "R restored: S151's cases against the shipped package once more"
mkdir -p "$WS/head"
git -C "$REPO" archive HEAD packages/nidana_dart_contracts/lib | tar -x -C "$WS/head"
if diff -r "$WS/head/packages/nidana_dart_contracts/lib" "$P/lib" > /dev/null; then
  echo "the copy's lib/ equals HEAD's"
else
  echo "the copy's lib/ differs from HEAD's"
fi
replay topic-model

rm -rf "$WS"
