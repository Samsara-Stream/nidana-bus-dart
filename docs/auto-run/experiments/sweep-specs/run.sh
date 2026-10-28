#!/usr/bin/env bash
# S156 evidence for the end-of-nidana.model spec touches. Read-only: it runs one
# throwaway program and reads git history and the package's sources.
# Run from the repository root: bash docs/auto-run/experiments/sweep-specs/run.sh
set -u
cd "$(git rev-parse --show-toplevel)"
LIB=packages/nidana_dart_contracts/lib
TEST=packages/nidana_dart_contracts/test/purity_test.dart

echo "== SDK"
fvm dart --version 2>&1

echo
echo "== P1. What the six calls D6's list misses do (effects.dart)"
fvm dart docs/auto-run/experiments/sweep-specs/effects.dart 2>&1

echo
echo "== P2. The token list purity_test.dart checks (const effects)"
awk '/^const List<String> effects/,/^];/' "$TEST"

echo
echo "== P3. Whether a listed token is a substring of each missed call (a hit would mean the test already catches it)"
for missed in 'Random.secure(' 'DateTime.timestamp(' 'Timer.run(' 'runZoned' 'Stream.periodic(' 'Future('; do
  hits=""
  while IFS= read -r tok; do
    case "$missed" in *"$tok"*) hits="$hits $tok";; esac
  done < <(awk '/^const List<String> effects/,/^];/' "$TEST" | sed -n "s/^ *'\(.*\)',$/\1/p")
  echo "$missed: listed tokens inside it:${hits:- none}"
done

echo
echo "== P4. The six missed tokens in the shipped libraries under $LIB (no output after this line means none)"
grep -rnF -e 'Random.secure(' -e 'DateTime.timestamp(' -e 'Timer.run(' -e 'runZoned' -e 'Stream.periodic(' -e 'Future(' "$LIB" || true

echo
echo "== P5. The lib/src/ directories each merged phase of nidana.model changed (D4)"
for m in $(git log --merges --format=%h --grep='^merge: nidana.model' HEAD); do
  ph=$(git log -1 --format=%s "$m" | grep -o 'nidana\.model\.[0-9]*' | head -1)
  dirs=$(git diff --name-only "$m^1" "$m" | grep "^$LIB/src/" | cut -d/ -f5 | sort -u | tr '\n' ' ')
  echo "$ph ($m): ${dirs:-none}"
done

echo
echo "== P6. nidana.model.11's change under $LIB/src/topic/"
m11=$(git log --merges --format=%h --grep='^merge: nidana.model.11 ' HEAD | head -1)
git diff "$m11^1" "$m11" -- "$LIB/src/topic/"

echo
echo "== P7. Where G3 and G7 first replay: the topology-ir replay of nidana.model.9 to .13's Gates, in phase order (nidana.model.14's is unrestricted)"
grep -n 'nidana_contract_check topology-ir' hsdd/spec/nidana.model.md | sed -n 's/^\([0-9]*\):.*\(nidana_contract_check topology-ir[^`]*\)`.*/line \1: \2/p'
