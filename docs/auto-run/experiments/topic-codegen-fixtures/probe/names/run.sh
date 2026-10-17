#!/usr/bin/env bash
# P3: which names may a generated registry member take? Writes one library per
# candidate name (a static field of an abstract final class), analyzes each
# under the workspace root's lint set and strict modes (analysis_options.yaml
# here), and prints the error codes, or clean. Candidates: Dart's reserved
# words, its built-in and contextual identifiers, and Object's members.
# Run from the experiment root: probe/names/run.sh > probe/names/output.txt
cd "$(dirname "$0")/../.." || exit 1
D=probe/names/cases
rm -rf $D && mkdir -p $D && cp probe/names/analysis_options.yaml $D/
for w in assert break case catch class const continue default do else enum extends false final finally for if in is new null rethrow return super switch this throw true try var void while with abstract as covariant deferred dynamic export extension external factory get implements import interface late library mixin operator part required set static typedef async await base hide of on sealed show sync when yield inline augment type hashCode runtimeType toString noSuchMethod; do
  printf '// P3: may a generated registry member be named %s?\nabstract final class R {\n  static final int %s = 1;\n}\n' "$w" "$w" > "$D/m_$w.dart"
done
for f in $D/m_*.dart; do
  w=$(basename $f .dart | sed 's/^m_//')
  r=$(fvm dart analyze --format=machine $f 2>&1 | grep -E '^(ERROR|WARNING|INFO)' | cut -d'|' -f1,3 | sort -u | tr '\n' ' ')
  echo "$w: ${r:-clean}"
done
rm -rf $D
