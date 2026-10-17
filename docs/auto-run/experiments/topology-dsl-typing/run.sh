#!/usr/bin/env bash
# topology-dsl-typing: which declaration form of the topology DSL's write path
# makes a handle of the wrong value type written to a topic a compile error
# (Spec §4.2)? Dart class generics are covariant, and inference solves a type
# argument that two arguments constrain to their least upper bound.
#
# lib/forms.dart declares the candidate forms; probe/write_forms.dart uses each
# with an unrelated type (lines *1), a subtype stream into a supertype topic
# (sound, lines *2) and a supertype stream into a subtype topic (unsound,
# lines *3). A line with no diagnostic compiled.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
fvm dart --version
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
echo
echo "### diagnostics: probe line tag, line, severity, code, message head"
fvm dart analyze --format=json probe/write_forms.dart | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  const src = require("fs").readFileSync("probe/write_forms.dart", "utf8").split("\n");
  const seen = new Set();
  for (const d of JSON.parse(s).diagnostics) {
    const l = d.location.range.start.line;
    const tag = (src[l - 1].match(/\/\/ line (\w+)/) || [])[1] || "-";
    seen.add(tag);
    console.log(tag, l, d.severity, d.code, "|", d.problemMessage.split("\n")[0]);
  }
  console.log();
  console.log("### probe lines with no diagnostic (they compile)");
  for (const line of src) {
    const m = line.match(/\/\/ line (\w+)/);
    if (m && !seen.has(m[1])) console.log(m[1], "|", line.trim());
  }
});'
