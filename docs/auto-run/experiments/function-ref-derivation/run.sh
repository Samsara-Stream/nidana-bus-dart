#!/usr/bin/env bash
# function-ref-derivation: what Function.toString() carries for each function
# form a topology declaration can pass, under every compiler the tree can
# meet: the VM (JIT, as `dart run` and `dart test` use it), AOT, AOT with
# --obfuscate (what `flutter build --obfuscate` passes to gen_snapshot),
# dart2js at -O1 and -O4 (Flutter web), and dart2wasm. Settles OQ-M1 for
# topology-ir@v1. Columns: form | toString() | derivation (bin/main.dart).
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
rm -rf build && mkdir -p build
fvm dart --version
fvm dart pub get > /dev/null 2>&1
echo "### JIT (fvm dart run)"
fvm dart run bin/main.dart
echo "### AOT (fvm dart compile exe)"
fvm dart compile exe bin/main.dart -o build/aot > /dev/null 2>&1 && ./build/aot
echo "### AOT obfuscated (fvm dart compile exe --extra-gen-snapshot-options=--obfuscate)"
fvm dart compile exe --extra-gen-snapshot-options=--obfuscate bin/main.dart -o build/aot_obf > /dev/null 2>&1 && ./build/aot_obf
for o in O1 O4; do
  echo "### dart2js -$o (fvm dart compile js), run by node $(node --version)"
  fvm dart compile js -$o bin/main.dart -o build/main_$o.js > /dev/null 2>&1
  node -e "globalThis.self = globalThis; globalThis.dartPrint = (s) => console.log(s); require('./build/main_$o.js');"
done
echo "### dart2wasm (fvm dart compile wasm), run by node $(node --version)"
fvm dart compile wasm bin/main.dart -o build/main.wasm > /dev/null 2>&1
cp bin/run_wasm.mjs build/ && node build/run_wasm.mjs
rm -rf build
