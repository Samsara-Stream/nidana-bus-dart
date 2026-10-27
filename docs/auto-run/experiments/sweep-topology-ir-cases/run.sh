#!/usr/bin/env bash
# sweep-topology-ir-cases: evidence for S154, the end-of-nidana.model
# governance sweep of topology-ir@v1, part 2 (hsdd-contract, compatible
# touches within v1: behavior cases and sample recordings). It works in two
# temporary copies of the committed tree (git archive HEAD), so packages/ is
# the shipped package in both and the repository's packages/ is never
# touched:
#   OLD holds the committed fixtures; NEW holds S154's working-tree
#   topology-ir fixture directory in their place.
# It records:
#   I: independent.py check: every valid/ document and render/ golden,
#      derived without the producer (HEAD's documents, S154's additions
#      written out by hand, the contract's rendering rules), against NEW's
#      files; HEAD's files of every sample derive unchanged.
#   P: the shipped package against S154's fixtures: topology-ir replayed
#      unrestricted (every set), the package's tests, the node gate's other
#      replays, and topic-codegen and nidana-checks (PENDING expected).
#   K: the cases S154 adds (case names in NEW and not in OLD).
#   F: how long the G13 ring case takes under dart test.
#   B: the behavior set of OLD and NEW, unseeded.
#   D: each seeded defect (defects.py), applied to both copies' package and
#      restored after: the committed suite (OLD) and S154's (NEW), with every
#      failing case named; for a renderer defect, also which of NEW's render/
#      goldens the seeded renderers miss, and where (samples.dart).
#   R: both copies' lib/ against HEAD's after the seeds.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}
OLD=$(mktemp -d "${T%/}/sweepcases-old.XXXXXX")
NEW=$(mktemp -d "${T%/}/sweepcases-new.XXXXXX")
HEADLIB=$(mktemp -d "${T%/}/sweepcases-head.XXXXXX")
IR=hsdd/contract/fixture/topology-ir
PKG=packages/nidana_dart_contracts
step() { echo; echo "### $*"; }
clip() { sed "s#$(cd "$OLD" && pwd -P)#{old}#g; s#$OLD#{old}#g; s#$(cd "$NEW" && pwd -P)#{new}#g; s#$NEW#{new}#g" | cut -c1-600; }
behavior() { # behavior <ws> <out>: the topology-ir behavior set, its result lines to <out>
  (cd "$1" && fvm dart run nidana_contract_check topology-ir --set behavior > "$1/behavior.out" 2>&1)
  grep -E '^(PASS|FAIL|ERROR|PENDING) behavior' "$1/behavior.out" \
    | sed -E 's/^(PASS|FAIL) behavior [^:]*: //; s/; failed-case \(/\n      failed-case (/g' > "$2"
}

step "S0 setup: two copies of the committed tree, resolved offline"
for ws in "$OLD" "$NEW"; do
  git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml packages hsdd | tar -x -C "$ws"
done
git -C "$REPO" archive HEAD packages | tar -x -C "$HEADLIB"
rm -rf "${NEW:?}/$IR" && cp -R "$REPO/$IR" "$NEW/$IR"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
for ws in "$OLD" "$NEW"; do (cd "$ws" && fvm dart pub get --offline 2>&1 | tail -n 1); done
echo "packages/ changes in the working tree: $(git -C "$REPO" status --porcelain packages | wc -l | tr -d ' ')"
echo "NEW's fixture files that differ from HEAD's:"
diff -rq "$OLD/$IR" "$NEW/$IR" | clip | sed 's/^/  /'

step "I independent.py: every sample's valid/ and render/ files derived without the producer, against NEW's"
python3 -I "$HERE/independent.py" check "$OLD/$IR" "$NEW/$IR"; echo "exit: $?"

step "P the shipped package against S154's fixtures (NEW)"
(cd "$NEW" && fvm dart run nidana_contract_check topology-ir > "$NEW/p.out" 2>&1; echo "exit: $?" >> "$NEW/p.out")
echo "-- nidana_contract_check topology-ir (every set)"
echo "PASS lines by set: $(grep -oE '^PASS [a-z]+' "$NEW/p.out" | sort | uniq -c | tr -s ' ' | tr '\n' ';')"
grep -E '^FAIL|^ERROR|^PENDING|^PASS behavior|fixtures:|^exit:' "$NEW/p.out" | clip
(cd "$NEW" && fvm dart test $PKG > "$NEW/t.out" 2>&1; echo "exit: $?" >> "$NEW/t.out")
echo "-- dart test $PKG"
grep -E 'All tests passed|Some tests failed|\[E\]$|^exit:' "$NEW/t.out" | sed 's/^[0-9:]* //' | sort -u | clip
(cd "$NEW" && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir > "$NEW/g.out" 2>&1; echo "exit: $?" >> "$NEW/g.out")
echo "-- nidana_contract_check topic-model topology-dsl topology-ir"
grep -E '^FAIL|^ERROR|^PENDING|^PASS behavior|fixtures:|^exit:' "$NEW/g.out" | clip
(cd "$NEW" && fvm dart run nidana_contract_check topic-codegen nidana-checks > "$NEW/o.out" 2>&1; echo "exit: $?" >> "$NEW/o.out")
echo "-- nidana_contract_check topic-codegen nidana-checks"
echo "outcomes: $(grep -oE '^(PASS|FAIL|ERROR|PENDING)' "$NEW/o.out" | sort | uniq -c | tr -s ' ' | tr '\n' ';')"
grep -E '^FAIL|^ERROR|fixtures:|^exit:' "$NEW/o.out" | clip

step "K the cases S154 adds: case names in NEW's conformance library and not in OLD's"
names() { grep -E "^    name: ['\"]G[0-9]+ " "$1/$IR/behavior/topology_ir_conformance.dart" | sed "s/^    name: //" | sort; }
echo "OLD: $(names "$OLD" | wc -l | tr -d ' ') cases; NEW: $(names "$NEW" | wc -l | tr -d ' ') cases"
comm -13 <(names "$OLD") <(names "$NEW") | sed 's/^/  + /' | cut -c1-200
echo "removed: $(comm -23 <(names "$OLD") <(names "$NEW") | wc -l | tr -d ' ')"

step "F the G13 ring case's time under dart test (NEW, shipped package)"
(cd "$NEW" && fvm dart test "$IR/behavior/nidana_dart_contracts_test.dart" --plain-name 'G13 a ring of 20000' -r expanded 2>&1 \
  | grep -E 'ring of 20000|All tests passed|Some tests failed' | sed -E 's/^([0-9:]+) .*G13 a ring.*/\1 the ring case (minutes:seconds since the run started)/' | tail -n 3)

step "B the behavior set unseeded"
behavior "$OLD" "$OLD/b.txt" & behavior "$NEW" "$NEW/b.txt" & wait
echo "-- committed suite (OLD)"; sed 's/^/   /' "$OLD/b.txt" | clip
echo "-- S154's suite (NEW)"; sed 's/^/   /' "$NEW/b.txt" | clip
for ws in "$OLD" "$NEW"; do cp "$HERE/samples.dart" "$ws/samples_check.dart"; done
echo "-- samples.dart, unseeded: OLD's goldens, then NEW's"
(cd "$OLD" && fvm dart run samples_check.dart 2>&1 | clip)
(cd "$NEW" && fvm dart run samples_check.dart 2>&1 | clip)

step "D seeded defects, each applied to both copies and restored after"
for key in $(python3 -I "$HERE/defects.py" --list | cut -f1); do
  label=$(python3 -I "$HERE/defects.py" --list | awk -F '\t' -v k="$key" '$1 == k { print $2 ": " $3 }')
  echo; echo "-- $key $label"
  ok=1
  for ws in "$OLD" "$NEW"; do
    rm -rf "$ws/lib.bak" && cp -R "$ws/$PKG/lib" "$ws/lib.bak"
    python3 -I "$HERE/defects.py" "$ws/$PKG" "$key" || ok=0
  done
  if [ $ok = 1 ]; then
    echo "   seed: $(diff -r "$OLD/lib.bak" "$OLD/$PKG/lib" | grep -cE '^[<>]') changed lines"
    behavior "$OLD" "$OLD/d.txt" & behavior "$NEW" "$NEW/d.txt" & wait
    echo "   committed suite: $(sed -n 1p "$OLD/d.txt")"; sed -n '2,$p' "$OLD/d.txt" | clip
    echo "   S154's suite:    $(sed -n 1p "$NEW/d.txt")"; sed -n '2,$p' "$NEW/d.txt" | clip
    case $key in R*)
      echo "   samples.dart over NEW's goldens, seeded:"
      (cd "$NEW" && fvm dart run samples_check.dart 2>&1 | clip) ;;
    esac
  else
    echo "   SEED FAILED"
  fi
  for ws in "$OLD" "$NEW"; do rm -rf "${ws:?}/$PKG/lib" && cp -R "$ws/lib.bak" "$ws/$PKG/lib"; done
done

step "R both copies' lib/ against HEAD's after the seeds"
for ws in "$OLD" "$NEW"; do
  diff -rq "$HEADLIB/$PKG/lib" "$ws/$PKG/lib" > /dev/null && echo "$(basename "$ws"): lib/ equals HEAD's" || echo "$(basename "$ws"): lib/ DIFFERS from HEAD's"
done
rm -rf "$OLD" "$NEW" "$HEADLIB"
echo "done"
