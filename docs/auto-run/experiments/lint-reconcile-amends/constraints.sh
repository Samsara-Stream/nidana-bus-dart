#!/usr/bin/env bash
# lint-reconcile-amends/constraints.sh: what a member's caret constraint,
# written while the workspace has no Flutter member and no nidana_dart_lint,
# does once one of them lands. ADR-002 item 9 sets a third-party constraint's
# lower bound to the version the committed lockfile resolves when the
# dependency is added; without Flutter and without the plugin's pins the
# workspace resolves analyzer 14.5.0 and test 1.33.0
# (../lint-pin-resolution/, L1).
#
#   K1 a member with test ^1.33.0 beside a Flutter member
#   K2 a member with test ^1.31.1 beside a Flutter member
#   K3 a member with analyzer ^14.5.0 beside a Flutter member
#   K4 a member with analyzer ^13.3.0 beside a Flutter member
#   K5 a member with analyzer ^13.3.0 and no Flutter member: what resolves
#   K6 nidana.model.1's member alone, nidana_contract_check's dependency row
#      of ADR-002 item 3 with open constraints: what the lockfile resolves, so
#      what lower bound ADR-002 item 9 gives `test`
#
# Each case is a fresh workspace in a temporary directory, resolved from no
# lockfile with `fvm dart pub get` at its root. Run from anywhere:
# ./constraints.sh > output-constraints.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=$(cd ../../../.. && pwd)
TMP=$(mktemp -d)
cp "$REPO/.fvmrc" "$TMP/"
step() { echo; echo "### $*"; }

# case $1 dir, $2 the pure member's dependency block, $3 yes when a Flutter member is present
make_case() {
  local d=$TMP/$1 deps=$2 flutter=$3
  mkdir -p "$d/packages/pure/lib"
  {
    echo "name: k_root"
    echo "publish_to: none"
    echo "environment:"
    echo "  sdk: ^3.13.0"
    echo "workspace:"
    [ "$flutter" = yes ] && echo "  - packages/flutter_member"
    echo "  - packages/pure"
  } > "$d/pubspec.yaml"
  printf 'name: pure\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n%s\n' "$deps" > "$d/packages/pure/pubspec.yaml"
  echo "int one() => 1;" > "$d/packages/pure/lib/pure.dart"
  if [ "$flutter" = yes ]; then
    mkdir -p "$d/packages/flutter_member/lib"
    printf 'name: flutter_member\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\ndependencies:\n  flutter:\n    sdk: flutter\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n' > "$d/packages/flutter_member/pubspec.yaml"
    echo "int two() => 2;" > "$d/packages/flutter_member/lib/flutter_member.dart"
  fi
}
resolve() {
  (cd "$TMP/$1" && fvm dart pub get > out.txt 2>&1; echo "pub get exit: $?"; grep -E '^(Because|So,|And because)' out.txt | head -4)
  [ -f "$TMP/$1/pubspec.lock" ] && awk '/^  [a-z_]+:$/{p=$1} p && /version:/{print "  resolved", p, $2; p=""}' "$TMP/$1/pubspec.lock" | grep -E ' (analyzer|test|test_api):'
}

fvm dart --version

step "K1 test ^1.33.0 beside a Flutter member"
make_case k1 $'dev_dependencies:\n  test: ^1.33.0' yes; resolve k1
step "K2 test ^1.31.1 beside a Flutter member"
make_case k2 $'dev_dependencies:\n  test: ^1.31.1' yes; resolve k2
step "K3 analyzer ^14.5.0 beside a Flutter member (with test ^1.31.1)"
make_case k3 $'dependencies:\n  analyzer: ^14.5.0\ndev_dependencies:\n  test: ^1.31.1' yes; resolve k3
step "K4 analyzer ^13.3.0 beside a Flutter member (with test ^1.31.1)"
make_case k4 $'dependencies:\n  analyzer: ^13.3.0\ndev_dependencies:\n  test: ^1.31.1' yes; resolve k4
step "K5 analyzer ^13.3.0, no Flutter member"
make_case k5 $'dependencies:\n  analyzer: ^13.3.0\ndev_dependencies:\n  test: ^1.31.1' no; resolve k5
step "K6 nidana_contract_check's dependency row alone, open constraints"
make_case k6 $'dependencies:\n  args: any\n  json_schema: any\n  matcher: any\n  package_config: any\n  path: any\ndev_dependencies:\n  test: any' no; resolve k6

rm -rf "$TMP"
