#!/usr/bin/env bash
# Runs structure_check.dart, the prototype of amended ADR-001's coverage
# (item 3) and layout (item 9) checks, over the nine contracts as they stand,
# then over a copy with seeded defects, each of which must be reported.
# The copy lives in work-structure/ (inside the repository, so fvm finds
# .fvmrc) and is removed at the end.
# Run from anywhere: ./structure.sh > structure-output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
CHECK=$HERE/structure_check.dart
step() { echo; echo "### $*"; }

step "S1 the nine contracts as they stand"
(cd "$REPO" && fvm dart run "$CHECK"; echo "exit: $?")

step "S2 seeded defects: a misspelt set directory, an unlisted data directory, a case with no table row, a file bullet without its covers clause, a reject header naming no id"
W=$HERE/work-structure && rm -rf "$W" && mkdir -p "$W/hsdd"
cp -R "$REPO/hsdd/contract" "$W/hsdd/"
F=$W/hsdd/contract/fixture
mv "$F/topic-model/reject" "$F/topic-model/rejcet"
mkdir -p "$F/topology-dsl/goldens" && touch "$F/topology-dsl/goldens/a.txt"
mkdir -p "$F/nidana-checks/invocation/scan-extra" && cp "$F/nidana-checks/invocation/scan-clean/args" "$F/nidana-checks/invocation/scan-extra/"
sed -i '' 's/ The file set covers G3 to G8, G12, G13 and G15 to G18\.//' "$W/hsdd/contract/topic-codegen.md"
sed -i '' 's|^// covers: .*|// covers: the closed families|' "$F/topology-ir/reject/ir_families_are_closed.dart"
(cd "$W" && fvm dart run "$CHECK"; echo "exit: $?")
rm -rf "$W"
