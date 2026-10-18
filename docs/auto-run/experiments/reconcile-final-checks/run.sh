#!/usr/bin/env bash
# reconcile-final-checks: evidence for step S42, the hsdd-reconcile run that
# drains nidana.integration's plan and flips every contract to
# `phase_ids: final` and `status: stable`.
#
#   C1 ADR-001 item 12 by reading, before the replay tool exists: item 3's
#      coverage and item 9's layout for the nine contracts as they now stand,
#      with the prototype of docs/auto-run/experiments/file-invocations/
#      (structure_check.dart, unchanged); every `hsdd/contract/` path a
#      `## Validation` section names exists; every binding file under a
#      `behavior/` directory is listed in its contract's `## Validation`.
#   C2 which directories the root `fvm dart analyze` of a workspace reads,
#      widening integration-plan-facts I6 to a member's `.dart_tool/`, where
#      topic-codegen@v1's `catalog` writes its entry point
#      (`{package}/.dart_tool/nidana_dart_codegen/`): a library with an
#      unused import is written to the root's and a member's `build/` and
#      `.dart_tool/`, and the root analyze reports what it reads.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
step() { echo; echo "### $*"; }

step "C1a item 3 coverage and item 9 layout, the nine contracts as they stand"
(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart; echo "exit: $?")

step "C1b every hsdd/contract/ path named by a Validation section exists"
cd "$REPO" || exit 1
for f in hsdd/contract/*.md; do
  [ "$(basename "$f")" = INDEX.md ] && continue
  slug=$(basename "$f" .md)
  n=0; missing=0
  for p in $(awk '/^## Validation/{p=1;next} p&&/^## /{p=0} p' "$f" | grep -o '`hsdd/contract/[^`]*`' | tr -d '`' | sort -u); do
    n=$((n+1)); [ -e "$p" ] || { missing=$((missing+1)); echo "  MISSING $p"; }
  done
  echo "$slug: $n paths, $missing missing"
done

step "C1c every binding under behavior/ is listed in its contract's Validation"
for d in hsdd/contract/fixture/*/behavior; do
  slug=$(basename "$(dirname "$d")")
  for b in "$d"/*_test.dart; do
    [ -e "$b" ] || continue
    name=$(basename "$b")
    if awk '/^## Validation/{p=1;next} p&&/^## /{p=0} p' "hsdd/contract/$slug.md" | grep -q "$name"; then s=listed; else s=UNLISTED; fi
    echo "$slug $name $s"
  done
done

step "C2 which directories the root analyze reads"
W=$HERE/work
rm -rf "$W" && mkdir -p "$W/packages/member/lib"
cat > "$W/pubspec.yaml" <<'YAML'
name: rfc_root
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/member
YAML
cat > "$W/packages/member/pubspec.yaml" <<'YAML'
name: member
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
YAML
printf "void g() {}\n" > "$W/packages/member/lib/member.dart"
cd "$W" || exit 1
fvm dart pub get > /dev/null 2>&1; echo "dart pub get exit: $?"
for d in build/ci .dart_tool/ci packages/member/build/ci packages/member/.dart_tool/ci packages/member/.dart_tool/nidana_dart_codegen; do
  mkdir -p "$d" && printf "import 'dart:async';\n\nvoid f() {}\n" > "$d/stray.dart"
done
echo "written: build/ci, .dart_tool/ci, packages/member/build/ci, packages/member/.dart_tool/ci, packages/member/.dart_tool/nidana_dart_codegen"
fvm dart analyze --format=machine 2>&1 | sed -e "s|$W|{root}|g" | cut -d'|' -f1,3,4,5; echo "exit: ${PIPESTATUS[0]}"
cd "$HERE" && rm -rf "$W"
echo "removed"
