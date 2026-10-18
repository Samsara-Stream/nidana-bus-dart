#!/usr/bin/env bash
# codegen-plan-facts, part B: how catalog's runners and the analyzer treat a
# fixture package that sits below a workspace member's test/ directory and is
# never resolved by pub (as nidana-checks@v1's scan cases' files/app packages
# are). See README.txt.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
TMP=$(mktemp -d)
step() { echo; echo "### $1"; }
scrub() { sed -e "s|$HERE/work|{work}|g" -e "s|$TMP|{tmp}|g" -e "s|$HOME|{home}|g"; }
written() { # files a run left in a fixture package, beyond its sources
  (cd "$1" && find . -type f -not -path './lib/*' -not -path './tool/*' -not -name pubspec.yaml -not -name '*.dart.cmp' | sort | tr '\n' ' '); echo; }

fvm dart --version 2>&1
rm -rf work && cp -R src work && cp ../../../../.fvmrc work/
(cd work && (fvm dart pub get --offline > "$TMP/pub.txt" 2>&1 || fvm dart pub get > "$TMP/pub.txt" 2>&1); echo "root pub get exit: $?")
PURE=work/packages/cpf_host/test/fixture/pure_app
FLUT=work/packages/cpf_host/test/fixture/flutter_app
CONFIG="$HERE/work/.dart_tool/package_config.json"
entry() { mkdir -p "$1/.dart_tool/nidana_dart_codegen" && cp src/entry/catalog_entry.dart "$1/.dart_tool/nidana_dart_codegen/catalog_entry.dart"; }

step "B1 dart run of the entry from the pure fixture package's root (no --packages)"
entry "$PURE"
(cd "$PURE" && fvm dart run -DOUT="$TMP/b1.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b1.log" 2>&1; echo "exit $?")
head -5 "$TMP/b1.log" | scrub
echo "wrote: $(cat "$TMP/b1.txt" 2>/dev/null || echo nothing)"
echo "left in the fixture package: $(written "$PURE")"

step "B2 dart run --packages=<workspace root config> from the same root"
rm -rf "$PURE/.dart_tool" "$PURE/pubspec.lock"; entry "$PURE"
(cd "$PURE" && fvm dart run --packages="$CONFIG" -DOUT="$TMP/b2.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b2.log" 2>&1; echo "exit $?")
head -5 "$TMP/b2.log" | scrub
echo "wrote: $(cat "$TMP/b2.txt" 2>/dev/null || echo nothing)"
echo "left in the fixture package: $(written "$PURE")"

step "B3 the pinned SDK's dart by path (Platform.resolvedExecutable of a dart run process), --packages, from the same root"
rm -rf "$PURE/.dart_tool" "$PURE/pubspec.lock"; entry "$PURE"
DART=$(cd work && fvm dart run "$HERE/tool/resolved_executable.dart")
echo "resolved executable: $(echo "$DART" | scrub)"
(cd "$PURE" && "$DART" run --packages="$CONFIG" -DOUT="$TMP/b3.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b3.log" 2>&1; echo "exit $?")
head -3 "$TMP/b3.log" | scrub
echo "wrote: $(cat "$TMP/b3.txt" 2>/dev/null || echo nothing)"
echo "left in the fixture package: $(written "$PURE")"

step "B4 flutter test --no-pub of the entry from the Flutter fixture package's root"
entry "$FLUT"
(cd "$FLUT" && fvm flutter test --no-pub --dart-define=OUT="$TMP/b4.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b4.log" 2>&1; echo "exit $?")
grep -m1 -o -E "StateError: Bad state: No element|tool_crash|No tests ran" "$TMP/b4.log"; grep -m1 -o "testCompilerBuildNativeAssets" "$TMP/b4.log"
echo "wrote: $(cat "$TMP/b4.txt" 2>/dev/null || echo nothing)"
echo "left in the fixture package: $(written "$FLUT")"

step "B5 the Flutter fixture under dart run --packages (expected: dart:ui missing)"
(cd "$FLUT" && fvm dart run --packages="$CONFIG" -DOUT="$TMP/b5.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b5.log" 2>&1; echo "exit $?")
grep -m1 -o "Dart library 'dart:ui' is not available on this platform" "$TMP/b5.log"
echo "wrote: $(cat "$TMP/b5.txt" 2>/dev/null || echo nothing)"

step "B6 a registration that imports its own package by package: URI, dart run --packages (the package is not in the workspace configuration)"
rm -rf "$PURE/.dart_tool" "$PURE/pubspec.lock"; entry "$PURE"
sed -i '' "s|import '../lib/pure_app.dart';|import 'package:pure_app/pure_app.dart';|" "$PURE/tool/nidana_catalog.dart"
(cd "$PURE" && fvm dart run --packages="$CONFIG" -DOUT="$TMP/b6.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b6.log" 2>&1; echo "exit $?")
grep -m1 -E "Error|Not found|Couldn't resolve" "$TMP/b6.log" | scrub
echo "wrote: $(cat "$TMP/b6.txt" 2>/dev/null || echo nothing)"
sed -i '' "s|import 'package:pure_app/pure_app.dart';|import '../lib/pure_app.dart';|" "$PURE/tool/nidana_catalog.dart"
rm -rf "$PURE/.dart_tool" "$FLUT/.dart_tool" "$PURE/pubspec.lock" "$FLUT/pubspec.lock"

step "B7 the workspace root's fvm dart analyze --fatal-infos with the two fixture packages below cpf_host/test/"
(cd work && fvm dart analyze --fatal-infos > "$TMP/b7.log" 2>&1; echo "exit $?")
scrub < "$TMP/b7.log" | grep -v '^Analyzing' | head -20

step "B8 the pure fixture copied to a temporary directory with a synthesized package configuration (workspace packages, absolute, plus itself); dart run from its root"
T8="$TMP/b8/pure_app"; mkdir -p "$TMP/b8" && cp -R src/packages/cpf_host/test/fixture/pure_app "$T8"
(cd work && fvm dart run "$HERE/tool/synthesize_config.dart" "$CONFIG" "$T8" pure_app)
entry "$T8"
(cd "$T8" && "$DART" run -DOUT="$TMP/b8.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b8.log" 2>&1; echo "exit $?")
head -3 "$TMP/b8.log" | scrub
echo "wrote: $(cat "$TMP/b8.txt" 2>/dev/null || echo nothing)"

step "B9 the Flutter fixture copied likewise; flutter test --no-pub from its root (the Flutter SDK holding the dart of B3, by path)"
T9="$TMP/b9/flutter_app"; mkdir -p "$TMP/b9" && cp -R src/packages/cpf_host/test/fixture/flutter_app "$T9"
(cd work && fvm dart run "$HERE/tool/synthesize_config.dart" "$CONFIG" "$T9" flutter_app)
entry "$T9"
FLUTTER="$(dirname "$(dirname "$(dirname "$(dirname "$DART")")")")/flutter"
echo "flutter: $(echo "$FLUTTER" | scrub)"
(cd "$T9" && "$FLUTTER" test --no-pub --dart-define=OUT="$TMP/b9.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b9.log" 2>&1; echo "exit $?")
grep -m1 -o -E "StateError: Bad state: No element|No tests ran" "$TMP/b9.log"; grep -m1 -o "testCompilerBuildNativeAssets" "$TMP/b9.log"
echo "wrote: $(cat "$TMP/b9.txt" 2>/dev/null || echo nothing)"

step "B11 the Flutter fixture copied to a temporary directory and resolved as a standalone package: flutter pub get --offline with cpf_contracts overridden by path (ADR-002 Q18), then flutter test --no-pub"
T11="$TMP/b11/flutter_app"; mkdir -p "$TMP/b11" && cp -R src/packages/cpf_host/test/fixture/flutter_app "$T11"
printf 'dependency_overrides:\n  cpf_contracts:\n    path: %s\n' "$HERE/work/packages/cpf_contracts" >> "$T11/pubspec.yaml"
(cd "$T11" && "$FLUTTER" pub get --offline > "$TMP/b11-pub.log" 2>&1; echo "pub get --offline exit $?")
grep -E "^(Because|Got dependencies|Changed)" "$TMP/b11-pub.log" | head -3 | scrub
entry "$T11"
(cd "$T11" && "$FLUTTER" test --no-pub --dart-define=OUT="$TMP/b11.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b11.log" 2>&1; echo "exit $?")
grep -m1 -o 'cannot run without a dependency on either "package:flutter_test" or "package:test"' "$TMP/b11.log"
echo "wrote: $(cat "$TMP/b11.txt" 2>/dev/null || echo nothing)"

step "B13 B11 with flutter_test added as a dev dependency of the standalone package"
printf 'dev_dependencies:\n  flutter_test:\n    sdk: flutter\n' >> "$T11/pubspec.yaml"
(cd "$T11" && "$FLUTTER" pub get --offline > "$TMP/b13-pub.log" 2>&1; echo "pub get --offline exit $?")
(cd "$T11" && "$FLUTTER" test --no-pub --dart-define=OUT="$TMP/b13.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b13.log" 2>&1; echo "exit $?")
tail -2 "$TMP/b13.log" | scrub
echo "wrote: $(cat "$TMP/b13.txt" 2>/dev/null || echo nothing)"

step "B12 the pure fixture resolved the same way (dart pub get --offline), then dart run without --packages"
T12="$TMP/b12/pure_app"; mkdir -p "$TMP/b12" && cp -R src/packages/cpf_host/test/fixture/pure_app "$T12"
printf 'dependency_overrides:\n  cpf_contracts:\n    path: %s\n' "$HERE/work/packages/cpf_contracts" >> "$T12/pubspec.yaml"
(cd "$T12" && "$DART" pub get --offline > "$TMP/b12-pub.log" 2>&1; echo "pub get --offline exit $?")
entry "$T12"
(cd "$T12" && "$DART" run -DOUT="$TMP/b12.txt" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/b12.log" 2>&1; echo "exit $?")
head -2 "$TMP/b12.log" | scrub
echo "wrote: $(cat "$TMP/b12.txt" 2>/dev/null || echo nothing)"

step "B10 the analyzer over the B8 and B9 copies and over the in-tree fixtures: what each class's superclass resolves to"
for d in "$T8" "$T9" "$HERE/$PURE" "$HERE/$FLUT"; do (cd work && fvm dart run cpf_host:resolve "$d" 2>&1 | scrub); done

rm -rf "$TMP" work
echo
echo "run exit 0"
