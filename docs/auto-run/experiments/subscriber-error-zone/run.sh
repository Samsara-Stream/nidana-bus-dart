#!/usr/bin/env bash
# subscriber-error-zone: where a bus.observe subscriber's error goes, and what
# each zone strategy does to virtual time (ADR-003 amendment, S58).
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
echo "### fvm dart --version"
fvm dart --version
echo
echo "### bin/main.dart (C1 to C14)"
fvm dart run bin/main.dart; echo "exit: $?"
echo
echo "### test/listen_zone_test.dart (T1 to T5 per strategy; some fail by design)"
fvm dart test --reporter expanded test/listen_zone_test.dart; echo "exit: $?"
