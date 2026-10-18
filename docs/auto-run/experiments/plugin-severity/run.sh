#!/usr/bin/env bash
# plugin-severity: settles what decides the severity of an analysis server
# plugin's diagnostic under `fvm dart analyze`, on the pinned analyzer 13.3.0
# and analysis_server_plugin 0.3.18.
#
# Two earlier experiments disagree on the surface:
#   workspace-layout (ADR-002 Context, Q11b, Q13, Q15): stand-in rules report
#     INFO|STATIC_WARNING;
#   nidana-checks-fixtures (nidana-checks@v1 G1): three rules report
#     WARNING|STATIC_WARNING and one INFO|STATIC_WARNING.
#
# packages/ps_lint is one plugin with four rules that flag the same
# expression and differ only in registration (warning rule or lint rule) and
# in the severity their LintCode declares (none, or WARNING). cases/ holds
# five option sets over one source file. Each case is analyzed by explicit
# path from this directory, as workspace-layout's Q13 and Q15 were.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
ROOT=$(pwd)
EXP=$(cd .. && pwd)
PUB="$HOME/.pub-cache/hosted/pub.dev"
step() { echo; echo "### $*"; }
paths() { sed -e "s|$ROOT|{root}|g" -e "s|$HOME|{home}|g"; }
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
analyze() { # $1 case, rest: extra flags
  local c=$1; shift
  fvm dart analyze "$@" --format=machine "cases/$c" 2>&1 | paths | cut -d'|' -f1-3,5,8 | sort
  echo "exit: ${PIPESTATUS[0]}"
}

step "setup: resolve, SDK"
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
versions pubspec.lock analyzer analysis_server_plugin
fvm dart --version

step "S1 the two earlier stand-ins: how each registers its rules and declares its code"
for f in "$EXP/workspace-layout/packages/wl_lint/lib/main.dart" \
         "$EXP/workspace-layout/packages/wl_lint_pinned/lib/main.dart" \
         "$EXP/nidana-checks-fixtures/packages/nidana_dart_lint/lib/main.dart" \
         "$EXP/nidana-checks-fixtures/packages/nidana_dart_lint/lib/src/rules.dart"; do
  echo "-- ${f#$EXP/}"
  grep -n -E 'register(Warning|Lint)Rule|LintCode\(|severity:' "$f" | sed 's/^/  /'
done
echo "-- what each reported (from its own output.txt)"
grep -E '^(INFO|WARNING)\|STATIC_WARNING\|NO_GLOBAL_BUS' "$EXP/workspace-layout/output.txt" | cut -d'|' -f1-3 | sort -u | sed 's/^/  workspace-layout:       /'
grep -E '^dart analyze \.:' "$EXP/nidana-checks-fixtures/output.txt" | sed 's/^dart analyze \.: /  nidana-checks-fixtures: /'

step "S2 the pinned sources: LintCode's default severity, the diagnostic type, and the plugin server's severity choice"
echo "-- analyzer 13.3.0 lib/src/dart/error/lint_codes.dart"
grep -n -E 'this\.severity = |DiagnosticType get type' "$PUB/analyzer-13.3.0/lib/src/dart/error/lint_codes.dart" | sed 's/^/  /'
echo "-- analyzer 13.3.0 lib/src/lint/registry.dart (which rules run)"
sed -n '/^  Iterable<AbstractAnalysisRule> enabled(Map<String, RuleConfig> ruleConfigs) {/,/^  }/p' "$PUB/analyzer-13.3.0/lib/src/lint/registry.dart" | sed 's/^/  /'
echo "-- analysis_server_plugin 0.3.18 lib/src/plugin_server.dart (the reported severity and type)"
grep -n -E 'severityMapping\[diagnostic.diagnosticCode\]|AnalysisErrorSeverity.INFO,|AnalysisErrorType.STATIC_WARNING|configuredSeverity != ConfiguredSeverity.enable|Fall back to the declared severity|var severityName = code.severity' \
  "$PUB/analysis_server_plugin-0.3.18/lib/src/plugin_server.dart" | sed 's/^/  /'

step "C1 no diagnostics section: warning rules at their declared severity, lint rules off"
analyze c1-defaults
lock=$(synthetic_lock ps_lint); echo "-- ps_lint synthetic package"; [ -n "$lock" ] && versions "$lock" analyzer analysis_server_plugin

step "C2 lint rules enabled with true: at their declared severity"
analyze c2-lint-enabled

step "C3 only warning_default (workspace-layout's shape) reports"
analyze c3-default-only
echo "-- with --fatal-infos"
analyze c3-default-only --fatal-infos

step "C4 only warning_declared (nidana-checks-fixtures' shape) reports"
analyze c4-declared-only

step "C5 configured severities override the declared ones; a configured severity enables a lint rule"
analyze c5-configured
