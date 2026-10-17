#!/usr/bin/env bash
# time-source-widget: the production provider under testWidgets (ADR-003).
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
echo "### widget_time_test.dart (W1 to W6)"
fvm flutter test --no-pub test/widget_time_test.dart; echo "exit: $?"
echo
echo "### pending_timer_test.dart (expected to fail)"
fvm flutter test --no-pub test/pending_timer_test.dart; echo "exit: $?"
