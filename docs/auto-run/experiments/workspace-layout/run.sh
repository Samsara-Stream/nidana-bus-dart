#!/usr/bin/env bash
# workspace-layout: settles the runtime facts ADR-002 rests on.
#
# The experiment is its own pub workspace laid out like the planned tree,
# with stand-in members (wl_* for nidana_*): a pure contracts package, a
# runtime on rxdart and clock, a pure navigation package, a Flutter adapter,
# a codegen package (build_runner builder plus a command entry), an analyzer
# plugin, a replay-tool stand-in and a Flutter integration app. Three extra
# plugin members probe how a plugin may depend on a sibling. ref/, hsdd/ and
# docs/ each hold a deliberate error that the root's excludes must hide.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
ROOT=$(pwd)
TMP=$(mktemp -d)
# fvm finds the pin by walking up for .fvmrc; temp directories need a copy.
cp "$ROOT/../../../../.fvmrc" "$TMP/.fvmrc"
step() { echo; echo "### $*"; }
versions() { # $1 lockfile, rest: package names
  local lock=$1; shift
  node -e '
    const s=require("fs").readFileSync(process.argv[1],"utf8");
    const re=/^  ([a-z_0-9]+):\n(?:    .*\n)*?    version: "([^"]+)"/gm; let m; const v={};
    while((m=re.exec(s))) v[m[1]]=m[2];
    for (const w of process.argv.slice(2)) console.log("  "+w.padEnd(24)+(v[w]||"-"));
  ' "$lock" "$@"
}
synthetic_lock() { # $1 plugin package directory name
  grep -l "packages/$1\$" "$HOME"/.dartServer/.plugin_manager/*/pubspec.yaml 2>/dev/null | head -1 | sed 's/pubspec.yaml$/pubspec.lock/'
}
rm -f packages/wl_integration/lib/auth.topics.g.dart

step "setup: resolve the workspace at the root"
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
echo "lockfiles below the root:"; find packages -name pubspec.lock | sed 's/^/  /'; echo "  (end)"

step "Q1 one resolution of the planned dependency set, Flutter member included"
versions pubspec.lock analyzer analysis_server_plugin build source_gen build_runner build_test dart_style \
  json_schema rxdart clock meta test test_api test_core matcher lints yaml path args package_config
fvm dart pub outdated 2>&1 | sed -n '/^direct dependencies/,/^transitive dependencies/p'

step "Q2 what caps analyzer below 14: three probes outside the workspace"
mkdir -p "$TMP/q2a" "$TMP/q2b" "$TMP/q2c"
cat > "$TMP/q2a/pubspec.yaml" <<'EOF'
name: q2a
publish_to: none
environment: {sdk: ^3.13.0}
dependencies:
  flutter: {sdk: flutter}
  analyzer: ^14.0.0
dev_dependencies:
  flutter_test: {sdk: flutter}
  test: any
EOF
cat > "$TMP/q2b/pubspec.yaml" <<'EOF'
name: q2b
publish_to: none
environment: {sdk: ^3.13.0}
dependencies:
  flutter: {sdk: flutter}
  analyzer: ^14.0.0
dev_dependencies:
  flutter_test: {sdk: flutter}
EOF
cat > "$TMP/q2c/pubspec.yaml" <<'EOF'
name: q2c
publish_to: none
environment: {sdk: ^3.13.0}
dependencies:
  analyzer: ^14.0.0
dev_dependencies:
  test: any
EOF
echo "-- q2a: Flutter + flutter_test + test + analyzer ^14"
(cd "$TMP/q2a" && fvm flutter pub get 2>&1 | grep -v '^Resolving\|^Downloading' | head -12; echo "exit: ${PIPESTATUS[0]}")
echo "-- q2b: Flutter + flutter_test + analyzer ^14, no test"
(cd "$TMP/q2b" && fvm flutter pub get > /dev/null 2>&1; echo "exit: $?"; versions pubspec.lock analyzer test_api)
echo "-- q2c: test + analyzer ^14, no Flutter"
(cd "$TMP/q2c" && fvm dart pub get > /dev/null 2>&1; echo "exit: $?"; versions pubspec.lock analyzer test test_core)

step "Q3 a hosted constraint on a sibling resolves to the local member; a mismatch fails"
fvm dart pub deps --style=list 2>/dev/null | grep -E '^- wl_contracts|^  - wl_contracts' | sort -u | head -3
cp -R "$ROOT" "$TMP/q3"; rm -rf "$TMP/q3/.dart_tool" "$TMP/q3/pubspec.lock"
sed -i '' 's/^version: 0.1.0/version: 0.2.0/' "$TMP/q3/packages/wl_contracts/pubspec.yaml"
(cd "$TMP/q3" && fvm dart pub get 2>&1 | grep -v '^Resolving' | head -6; echo "exit: ${PIPESTATUS[0]}")

step "Q4 glob members (workspace: [packages/*]) on the pinned SDK"
cp -R "$ROOT" "$TMP/q4"; rm -rf "$TMP/q4/.dart_tool" "$TMP/q4/pubspec.lock"
node -e '
  const fs=require("fs"),f=process.argv[1];let s=fs.readFileSync(f,"utf8");
  s=s.replace(/workspace:\n(  - .*\n)+/,"workspace:\n  - packages/*\n");fs.writeFileSync(f,s);' "$TMP/q4/pubspec.yaml"
(cd "$TMP/q4" && fvm dart pub get > /dev/null 2>&1; echo "exit: $?"; fvm dart pub workspace list 2>&1 | sed 's|'"$TMP"'/q4|{q4}|')

step "Q5 pub get run inside a member resolves the whole workspace at the root"
cp -R "$ROOT" "$TMP/q5"; rm -rf "$TMP/q5/.dart_tool" "$TMP/q5/pubspec.lock"
(cd "$TMP/q5/packages/wl_contracts" && fvm dart pub get > /dev/null 2>&1; echo "exit: $?")
ls "$TMP/q5/pubspec.lock" "$TMP/q5/packages/wl_contracts/pubspec.lock" 2>&1 | sed 's|'"$TMP"'/q5|{q5}|'

step "Q6a an example/ with its own pubspec below a member, not a member"
cp -R "$ROOT" "$TMP/q6a"; mkdir -p "$TMP/q6a/packages/wl_runtime/example/bin"
cat > "$TMP/q6a/packages/wl_runtime/example/pubspec.yaml" <<'EOF'
name: wl_runtime_example
publish_to: none
environment: {sdk: ^3.13.0}
dependencies:
  wl_runtime: {path: ..}
EOF
echo "-- root pub get with the non-member example present"
(cd "$TMP/q6a" && fvm dart pub get 2>&1 | grep -v '^Resolving\|^Downloading\|^Got\|^  \|^No dep\|newer versions\|pub outdated' | head -6; echo "exit: ${PIPESTATUS[0]}")
echo "-- pub get inside the example (its own resolution)"
(cd "$TMP/q6a/packages/wl_runtime/example" && fvm dart pub get 2>&1 | grep -v '^Resolving' | head -6; echo "exit: ${PIPESTATUS[0]}")

step "Q6b the same example as a nested workspace member"
cp -R "$ROOT" "$TMP/q6b"; rm -rf "$TMP/q6b/.dart_tool" "$TMP/q6b/pubspec.lock"; mkdir -p "$TMP/q6b/packages/wl_runtime/example/bin"
printf 'workspace:\n  - example\n' >> "$TMP/q6b/packages/wl_runtime/pubspec.yaml"
cat > "$TMP/q6b/packages/wl_runtime/example/pubspec.yaml" <<'EOF'
name: wl_runtime_example
publish_to: none
environment: {sdk: ^3.13.0}
resolution: workspace
dependencies:
  wl_runtime: ^0.1.0
EOF
(cd "$TMP/q6b" && fvm dart pub get > /dev/null 2>&1; echo "exit: $?"; fvm dart pub workspace list 2>&1 | grep -i example | sed 's|'"$TMP"'/q6b|{q6b}|')
echo "-- does the nested member ship inside wl_runtime's archive? (publish dry-run file list)"
(cd "$TMP/q6b" && fvm dart pub -C packages/wl_runtime publish --dry-run 2>&1 | grep -E 'example|pubspec' | head -6)

step "Q6c an example/ with no pubspec is part of its member"
fvm dart analyze packages/wl_contracts/example; echo "exit: $?"
fvm dart run packages/wl_contracts/example/example.dart; echo "exit: $?"

step "Q7 codegen: the build_runner builder in the Flutter integration member"
(cd packages/wl_integration && fvm dart run build_runner build --delete-conflicting-outputs 2>&1 | grep -E 'Succeeded|Failed|error|Error|wrote|output' | head -5; echo "exit: ${PIPESTATUS[0]}")
cat packages/wl_integration/lib/auth.topics.g.dart

step "Q8 codegen: the command entry outside build_runner, from the root, same bytes as the builder"
fvm dart run wl_codegen:generate packages/wl_integration/lib "$TMP/q8-out" | sed 's|'"$TMP"'|{tmp}|'; echo "exit: ${PIPESTATUS[0]}"
cmp "$TMP/q8-out/auth.topics.g.dart" packages/wl_integration/lib/auth.topics.g.dart && echo "builder output and command output are identical"

step "Q9 member executables run from the root by package:executable"
fvm dart run wl_lint:scan a b; echo "exit: $?"
fvm dart run wl_contract_check topic-model --set surface; echo "exit: $?"

step "Q10 tests: pure member under dart test, Flutter members under flutter test"
(cd packages/wl_runtime && fvm dart test 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")
(cd packages/wl_runtime_flutter && fvm flutter test --no-pub 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")
(cd packages/wl_integration && fvm flutter test --no-pub 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}")

step "Q11 workspace-wide analyze at the root: excludes, inherited lint set, and a plugin declared in a member's own options"
fvm dart analyze --format=machine 2>&1 | sed 's|'"$ROOT"'|{root}|' | sort; echo "exit: ${PIPESTATUS[0]}"

step "Q11b the same plugin enabled in the workspace root options instead: it applies to every member"
cp -R "$ROOT" "$TMP/q11b"
printf 'plugins:\n  wl_lint:\n    path: packages/wl_lint\n' >> "$TMP/q11b/analysis_options.yaml"
printf 'include: ../../analysis_options.yaml\n' > "$TMP/q11b/packages/wl_integration/analysis_options.yaml"
(cd "$TMP/q11b" && fvm dart pub get > /dev/null 2>&1 && fvm dart analyze --format=machine 2>&1 | grep -E 'NO_GLOBAL_BUS|PLUGIN|plugin' | sed 's|'"$TMP"'/q11b|{q11b}|' | sort; echo "exit: ${PIPESTATUS[0]}")
lock=$(synthetic_lock wl_lint); echo "-- wl_lint synthetic package"; [ -n "$lock" ] && versions "$lock" analyzer analysis_server_plugin

step "Q11d with the plugin enabled at the root, explicit-path analysis of excluded hsdd/ trees"
mkdir -p "$TMP/q11b/hsdd/contract/fixture/demo/reject"
printf 'analyzer:\n  language:\n    strict-casts: true\n    strict-inference: true\n    strict-raw-types: true\n' > "$TMP/q11b/hsdd/contract/fixture/analysis_options.yaml"
cp hsdd/inputs/member/app.dart "$TMP/q11b/hsdd/contract/fixture/demo/reject/global.dart"
cp hsdd/inputs/member/app.dart "$TMP/q11b/hsdd/loose.dart"
echo "-- a fixture under a nested options file with no plugins section"
(cd "$TMP/q11b" && fvm dart analyze --format=machine hsdd/contract/fixture/demo 2>&1 | sed 's|.*/q11b|{q11b}|'; echo "exit: ${PIPESTATUS[0]}")
echo "-- a file under hsdd/ with no nested options file"
(cd "$TMP/q11b" && fvm dart analyze --format=machine hsdd/loose.dart 2>&1 | sed 's|.*/q11b|{q11b}|'; echo "exit: ${PIPESTATUS[0]}")

step "Q11c a root-enabled plugin that does not compile"
echo 'this is not dart' >> "$TMP/q11b/packages/wl_lint/lib/main.dart"
(cd "$TMP/q11b" && fvm dart analyze --format=machine 2>&1 | grep -vE 'IMPLEMENTATION_IMPORTS|INVALID_DEPENDENCY|STRICT_RAW_TYPE|wl_lint/lib/main.dart' | sed 's|'"$TMP"'/q11b|{q11b}|;s|'"$HOME"'|{home}|g' | head -4; echo "exit: ${PIPESTATUS[0]}")
rm -rf "$TMP/q11b"

step "Q12 plugin with a hosted constraint on an unpublished sibling, enabled by relative path"
fvm dart analyze --format=machine hsdd/inputs/hosted 2>&1 | sed 's|'"$ROOT"'|{root}|;s|'"$HOME"'|{home}|g' | head -12; echo "exit: ${PIPESTATUS[0]}"

step "Q13 plugin with a path dependency on a sibling, enabled by relative path"
fvm dart analyze --format=machine hsdd/inputs/path 2>&1 | sed 's|'"$ROOT"'|{root}|' | head -6; echo "exit: ${PIPESTATUS[0]}"

step "Q14 the plugin's run-time resolution is the analysis server's synthetic package, not the workspace"
for p in wl_lint wl_lint_path; do
  echo "-- $p: workspace lockfile"; versions pubspec.lock analyzer analysis_server_plugin
  lock=$(synthetic_lock $p)
  echo "-- $p: synthetic package in ~/.dartServer/.plugin_manager"; [ -n "$lock" ] && versions "$lock" analyzer analysis_server_plugin wl_contracts
done

step "Q15 plugin pinning analyzer and analysis_server_plugin to the workspace lockfile's versions"
fvm dart analyze --format=machine hsdd/inputs/pinned 2>&1 | sed 's|'"$ROOT"'|{root}|' | head -6; echo "exit: ${PIPESTATUS[0]}"
lock=$(synthetic_lock wl_lint_pinned); echo "-- synthetic package"; [ -n "$lock" ] && versions "$lock" analyzer analysis_server_plugin

step "Q16 publish dry-run: hosted sibling constraints and resolution: workspace versus a path dependency"
echo "-- wl_runtime (hosted constraint on wl_contracts)"
fvm dart pub -C packages/wl_runtime publish --dry-run 2>&1 | sed -n '/^Validating package/,$p' | grep -E '^Package validation|^\* '
echo "-- wl_lint_path (path dependency on wl_contracts)"
fvm dart pub -C packages/wl_lint_path publish --dry-run 2>&1 | sed -n '/^Validating package/,$p' | grep -E '^Package validation|^\* '


step "Q17 a rule-testing package next to the pinned analyzer"
(cd packages/wl_lint_pinned && fvm dart pub add --dev analyzer_testing --dry-run 2>&1 | grep -E 'analyzer_testing|analyzer |Would change|version solving|Because' | head -4)

step "Q18 an app outside the workspace consuming unpublished members"
mkdir -p "$TMP/q18/app"
cp -R packages "$TMP/q18/packages"
cat > "$TMP/q18/app/pubspec.yaml" <<'YAML'
name: q18_app
publish_to: none
environment: {sdk: ^3.13.0}
dependencies:
  wl_runtime: {path: ../packages/wl_runtime}
YAML
echo "-- path dependency on wl_runtime alone"
(cd "$TMP/q18/app" && fvm dart pub get 2>&1 | grep -E 'Because|So,|Got dependencies' | head -3; echo "exit: ${PIPESTATUS[0]}")
printf 'dependency_overrides:\n  wl_contracts: {path: ../packages/wl_contracts}\n' >> "$TMP/q18/app/pubspec.yaml"
echo "-- plus a dependency override for every unpublished sibling it reaches"
(cd "$TMP/q18/app" && fvm dart pub get 2>&1 | grep -E 'Because|So,|Got dependencies' | head -3; echo "exit: ${PIPESTATUS[0]}")

rm -rf "$TMP"
