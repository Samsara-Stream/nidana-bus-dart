#!/usr/bin/env bash
# catalog-loading: which runner loads a registration library, and do the
# runners record the same definitions? See README.txt.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
STANDIN=../flutter-binding-fixtures/packages/nidana_dart_contracts
TMP=$(mktemp -d)
TIMEFORMAT='elapsed %Rs'

step() { echo; echo "### $1"; }
show() { if [ -f "$1" ]; then echo "wrote $(basename "$1"), $(wc -c < "$1" | tr -d ' ') bytes; transformers: $(grep -o '"name": "[^"]*"' "$1" | sort -u | tr '\n' ' ')"; else echo "no file written"; fi; }

fvm dart --version
rm -rf work && cp -R src work
mkdir -p work/packages/nidana_dart_contracts
cp -R "$STANDIN/lib" "$STANDIN/pubspec.yaml" work/packages/nidana_dart_contracts/
(cd work && (fvm flutter pub get --offline > "$TMP/pub.txt" 2>&1 || fvm flutter pub get > "$TMP/pub.txt" 2>&1); echo "pub get exit: $?")

entry() { # entry <package> <file name> [registration import]
  local dir="work/packages/$1/.dart_tool/nidana_dart_codegen"
  mkdir -p "$dir"
  if [ -n "$3" ]; then
    sed "s|'../../tool/nidana_catalog.dart'|'$3'|" src/entry/catalog_entry.dart > "$dir/$2"
  else
    cp src/entry/catalog_entry.dart "$dir/$2"
  fi
}

step "T1 pure package, fvm dart run on the generated entry (package domain)"
entry domain catalog_entry.dart
(cd work/packages/domain && time fvm dart run -DOUT="$TMP/domain-dart.json" .dart_tool/nidana_dart_codegen/catalog_entry.dart; echo "exit $?")
show "$TMP/domain-dart.json"

step "T2 Flutter-importing registration, fvm dart run (package app)"
entry app catalog_entry.dart
(cd work/packages/app && fvm dart run -DOUT="$TMP/app-dart.json" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/t2.txt" 2>&1; echo "exit $?")
grep -m1 "dart:ui" "$TMP/t2.txt" | sed 's|.*/packages/flutter/|{flutter}/packages/flutter/|'
show "$TMP/app-dart.json"

step "T3 the same entry under fvm flutter test: a main() that declares no test, in a file outside test/ whose name does not end in _test.dart"
(cd work/packages/app && time fvm flutter test --no-pub --dart-define=OUT="$TMP/app-flutter.json" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/t3.txt" 2>&1; echo "exit $?")
tail -2 "$TMP/t3.txt"
show "$TMP/app-flutter.json"

step "T4 the domain registration recorded under the Flutter tester (entry in package app, relative import), compared with T1"
entry app catalog_entry_domain.dart '../../../domain/tool/nidana_catalog.dart'
(cd work/packages/app && fvm flutter test --no-pub --dart-define=OUT="$TMP/domain-flutter.json" .dart_tool/nidana_dart_codegen/catalog_entry_domain.dart > "$TMP/t4.txt" 2>&1; echo "exit $?")
tail -1 "$TMP/t4.txt"
show "$TMP/domain-flutter.json"
if cmp -s "$TMP/domain-dart.json" "$TMP/domain-flutter.json"; then echo "T1 and T4 documents: byte-identical"; else echo "T1 and T4 documents: DIFFER"; diff "$TMP/domain-dart.json" "$TMP/domain-flutter.json" | head -20; fi

step "T5 a Flutter package without flutter_test as a dev dependency, under fvm flutter test (package app_bare)"
entry app_bare catalog_entry.dart
(cd work/packages/app_bare && fvm flutter test --no-pub --dart-define=OUT="$TMP/bare-flutter.json" .dart_tool/nidana_dart_codegen/catalog_entry.dart > "$TMP/t5.txt" 2>&1; echo "exit $?")
tail -2 "$TMP/t5.txt" | sed "s|$HERE|{here}|g"
show "$TMP/bare-flutter.json"

step "T6 a throwing registration under fvm flutter test: does the exit code report it?"
mkdir -p work/packages/app/tool/broken
cat > work/packages/app/tool/broken/nidana_catalog.dart <<'EOF'
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
Iterable<Topology> catalogTopologies() => throw StateError('a topology that cannot be constructed');
EOF
entry app catalog_entry_broken.dart '../../tool/broken/nidana_catalog.dart'
(cd work/packages/app && fvm flutter test --no-pub --dart-define=OUT="$TMP/broken.json" .dart_tool/nidana_dart_codegen/catalog_entry_broken.dart > "$TMP/t6.txt" 2>&1; echo "exit $?")
grep -m1 -o "Bad state: a topology that cannot be constructed" "$TMP/t6.txt"
show "$TMP/broken.json"

step "T7 the pure entry from a directory outside the package, dart run --packages (the pinned SDK's dart by path: fvm needs .fvmrc above the working directory)"
mkdir -p "$TMP/outside"
sed "s|'../../tool/nidana_catalog.dart'|'file://$HERE/work/packages/domain/tool/nidana_catalog.dart'|" src/entry/catalog_entry.dart > "$TMP/outside/catalog_entry.dart"
DART="$(fvm flutter --version --machine 2>/dev/null | sed -n 's/.*"flutterRoot": *"\([^"]*\)".*/\1/p')/bin/dart"
(cd "$TMP/outside" && "$DART" run --packages="$HERE/work/.dart_tool/package_config.json" -DOUT="$TMP/outside.json" catalog_entry.dart > "$TMP/t7.txt" 2>&1; echo "exit $?")
tail -1 "$TMP/t7.txt" | sed "s|$TMP|{tmp}|g"
show "$TMP/outside.json"
cmp -s "$TMP/domain-dart.json" "$TMP/outside.json" && echo "T1 and T7 documents: byte-identical"

echo
echo "### The T1 document"
cat "$TMP/domain-dart.json"

rm -rf "$TMP" work
echo "run exit 0"
