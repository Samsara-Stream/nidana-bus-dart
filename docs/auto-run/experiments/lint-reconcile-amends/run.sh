#!/usr/bin/env bash
# lint-reconcile-amends: checks the nidana-checks@v1 fixture changes that
# hsdd-reconcile made when it drained nidana.tooling.lint's plan (S37):
#
#   amendment (c)  raw_string_topic accepts the whole initializer of any static
#                  field, of a class, mixin, enum, extension or extension type,
#                  const, final, late or none of these (G4); recorded as
#                  accepted forms at the end of analyze-raw-string-topic, whose
#                  stdout does not change
#   amendment (d)  unflagged_sensitive_topic's {1}, for a value type that
#                  contains more than one known-sensitive type, names the first
#                  a depth-first search meets: the alias, the type itself, its
#                  type arguments in order, or a record's positional fields in
#                  order and then its named fields by name; recorded as four
#                  reported topics at the end of analyze-sensitive-fatal-infos
#
# It reuses the stand-in workspace of ../nidana-checks-fixtures/ (the stand-in
# nidana_dart_lint on analyzer 13.3.0 and analysis_server_plugin 0.3.18, the
# stand-in nidana packages and the replay stand-in tool/replay.dart), copied
# into a temporary directory together with the repository's nidana-checks
# fixtures, either as amended in the working tree or as committed at HEAD.
#
#   T0 the fixture change against HEAD
#   T1 the amended fixtures: every recorded invocation passes on the stand-in
#   T2 the committed fixtures: every recorded invocation passes on the same
#      stand-in, which already meets (c) and (d)
#   T3 seeded stand-ins, each reading (c) or (d) another way: each fails the
#      amended case of the clause it breaks, and passes every committed case,
#      which is the coverage the change adds
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=$(cd ../../../.. && pwd)
NCF=$REPO/docs/auto-run/experiments/nidana-checks-fixtures
F=hsdd/contract/fixture
I=$F/nidana-checks/invocation
TMP=$(mktemp -d)
# Copies below $TMP find the SDK pin through this copy of the repository's .fvmrc.
cp "$REPO/.fvmrc" "$TMP/"
step() { echo; echo "### $*"; }
paths() { sed -e "s|$TMP|{tmp}|g" -e "s|$REPO|{repo}|g" -e "s|$HOME|{home}|g"; }

# fixtures $1 (workspace) $2 (worktree | HEAD): replace the workspace's copy
fixtures() {
  rm -rf "$1/hsdd" && mkdir -p "$1/$F"
  if [ "$2" = worktree ]; then
    cp "$REPO/$F/analysis_options.yaml" "$1/$F/"
    cp -R "$REPO/$F/nidana-checks" "$1/$F/"
  else
    (cd "$REPO" && git archive HEAD $F/analysis_options.yaml $F/nidana-checks) | tar -x -C "$1"
  fi
}
workspace() { # $1 directory: the stand-in workspace, without fixtures
  rsync -a --exclude probe --exclude hsdd --exclude output.txt "$NCF/" "$1/"
}
summary() { grep -E -o '^(PASS|FAIL) [a-z0-9-]+|^[0-9]+ of [0-9]+ invocations pass'; }

step "setup"
fvm dart --version
awk '/^  [a-z_]+:$/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' "$NCF/pubspec.lock" | grep -E ' (analyzer|analysis_server_plugin):'

step "T0 the fixture change against HEAD"
git -C "$REPO" diff --stat HEAD -- "$F/nidana-checks"
git -C "$REPO" diff HEAD -- "$I/analyze-sensitive-fatal-infos/stdout" | grep -E '^[+-][^+-]'

WS=$TMP/ws
workspace "$WS"

step "T1 the amended fixtures, every recorded invocation, on the stand-in"
fixtures "$WS" worktree
(cd "$WS" && fvm dart run tool/replay.dart $I | paths; echo "exit: ${PIPESTATUS[0]}")

step "T2 the committed fixtures, every recorded invocation, on the same stand-in"
fixtures "$WS" HEAD
(cd "$WS" && fvm dart run tool/replay.dart $I | summary; echo "exit: ${PIPESTATUS[0]}")

L=packages/nidana_dart_lint/lib/src/rules.dart
seeded() { # $1 label, $2 python patch; then the cases to replay
  local label=$1 patch=$2; shift 2
  local copy=$TMP/seed-$label
  workspace "$copy"
  (cd "$copy" && python3 -I -c "$patch") || { echo "patch failed"; return; }
  fixtures "$copy" worktree
  echo "amended:"; (cd "$copy" && fvm dart run tool/replay.dart $I "$@" | summary)
  fixtures "$copy" HEAD
  echo "committed:"; (cd "$copy" && fvm dart run tool/replay.dart $I "$@" | summary)
}
sub() { echo "import sys; p='$L'; s=open(p).read(); a='''$1'''; b='''$2'''; assert s.count(a) == 1, 'patch target missing'; open(p,'w').write(s.replace(a,b))"; }

RAW="analyze-clean analyze-raw-string-topic analyze-human"
SENS="analyze-clean analyze-unflagged-sensitive-topic analyze-sensitive-fatal-infos analyze-human"

step "T3 seeded stand-ins"
echo "-- C1 (c) read as 'of any class': a static field of a mixin, enum, extension or extension type is reported"
seeded c1 "$(sub '  return fields is FieldDeclaration && fields.isStatic;' '  return fields is FieldDeclaration && fields.isStatic && fields.thisOrAncestorOfType<ClassDeclaration>() != null;')" $RAW
echo "-- C2 (c) read as 'static const or static final': a late or mutable static field is reported"
seeded c2 "$(sub '  return fields is FieldDeclaration && fields.isStatic;' '  return fields is FieldDeclaration && fields.isStatic && (fields.fields.isConst || fields.fields.isFinal) && !fields.fields.isLate;')" $RAW
echo "-- D1 (d) type arguments searched last to first"
seeded d1 "$(sub '    for (final DartType a in type.typeArguments) {' '    for (final DartType a in type.typeArguments.reversed) {')" $SENS
echo "-- D2 (d) a record's named fields searched before its positional fields"
seeded d2 "$(sub '      for (final RecordTypePositionalField p in type.positionalFields) p.type,
      for (final RecordTypeNamedField n in type.namedFields) n.type,' '      for (final RecordTypeNamedField n in type.namedFields) n.type,
      for (final RecordTypePositionalField p in type.positionalFields) p.type,')" $SENS
echo "-- D3 (d) a record's named fields searched against their name order"
seeded d3 "$(sub '      for (final RecordTypeNamedField n in type.namedFields) n.type,' '      for (final RecordTypeNamedField n in type.namedFields.reversed) n.type,')" $SENS
echo "-- D4 (d) the alias searched after the type it names"
seeded d4 "$(sub '  final InstantiatedTypeAliasElement? alias = type.alias;
  if (alias != null && (_namedSensitive(alias.element.name) || _annotatedSensitive(alias.element))) {
    return alias.element.name;
  }
  if (type is InterfaceType) {' '  if (type is InterfaceType) {')
$(sub '      if (found != null) return found;
    }
  }
  return null;
}' '      if (found != null) return found;
    }
  }
  final InstantiatedTypeAliasElement? alias = type.alias;
  if (alias != null && (_namedSensitive(alias.element.name) || _annotatedSensitive(alias.element))) {
    return alias.element.name;
  }
  return null;
}')" $SENS

rm -rf "$TMP"
