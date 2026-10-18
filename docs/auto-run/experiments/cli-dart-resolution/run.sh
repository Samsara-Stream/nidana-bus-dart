#!/bin/sh
# Run from the repository root.
cd "$(dirname "$0")"
echo "### fvm dart run probe.dart (PATH as the shell has it)"
fvm dart run probe.dart
echo
echo "### fvm dart run probe.dart with PATH stripped of every dart"
env PATH=/usr/bin:/bin:$(dirname "$(command -v fvm)") fvm dart run probe.dart
