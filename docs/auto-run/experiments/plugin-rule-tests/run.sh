#!/usr/bin/env bash
# plugin-rule-tests: settles, on the pinned SDK with analyzer 13.3.0,
# analysis_server_plugin 0.3.18, analyzer_testing 0.3.2 and test 1.31.1 (the
# workspace's versions, ADR-002 Consequences):
#   Q1 analyzer_testing's AnalysisRuleTest runs under plain package:test, its
#      setUp and tearDown called from package:test's hooks, so
#      nidana_dart_lint needs no test_reflective_loader (ADR-002 item 3 lists
#      analyzer_testing and test as its only dev dependencies); a rule's
#      diagnostic is matched with its offset, length and message;
#   Q2 a rule's decision written as a pure function of a resolved node,
#      returning a value, is tested by resolving an in-memory library with
#      resolveFile and calling it on the nodes found, with no rule reporting;
#   Q3 a library under the test package's test/ directory is skipped through
#      RuleContext.isInTestDirectory, in memory.
# Stand-in packages added with newPackage carry the package and element names
# recognition matches (nidana-checks@v1 Recognition), one declaring under
# lib/src/ and one same-named class of another package; newPackage must run
# before AnalysisRuleTest.setUp, which writes the package configuration.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
fvm dart --version
fvm dart pub get --offline > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  [a-z_]+:$/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock | grep -E ' (analyzer|analysis_server_plugin|analyzer_testing|test|test_reflective_loader):'
grep -c test_reflective_loader pubspec.lock | sed 's/^/test_reflective_loader entries in the lockfile: /'
fvm dart test test/rules; echo "exit: $?"
