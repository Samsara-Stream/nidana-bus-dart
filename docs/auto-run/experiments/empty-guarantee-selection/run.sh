#!/usr/bin/env bash
# empty-guarantee-selection: S31 checks nidana.runtime's gate assumption that
# the replay tool passes bus-api@v1's bus_activation_test.dart, which binds
# topology-dsl@v1's live suite, when the gate's --guarantee list names no
# topology-dsl@v1 id (nidana.runtime.5 to .11), against nidana.model D2 item 4
# and nidana.model.6's scope ("--guarantee becomes a test-name filter anchored
# at the start of the name"). test/live_binding_test.dart stands in for that
# binding: two cases named like the live suite's.
#   E1 a filter that admits a case runs it;
#   E2 a filter that admits no case: what dart test reports and exits with;
#   E3 nidana.runtime.11's bare bus-api ids applied as a name filter to the
#      binding, as a tool that ignores which suite a binding runs would do.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
step() { echo; echo "### $*"; }
fvm dart --version
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
step "E1 filter admits a case: --name '^(G18) '"
fvm dart test --name '^(G18) ' test/live_binding_test.dart; echo "exit: $?"
step "E2 filter admits no case (a bus-api id only): --name '^(G3) '"
fvm dart test --name '^(G3) ' test/live_binding_test.dart; echo "exit: $?"
step "E3 the bare bus-api ids of nidana.runtime.11 applied as a name filter to the live binding"
fvm dart test --name '^(G1|G3|G4|G7|G8|G10|G11|G12|G13|G15|G17|G18|G19|G20|G21|G24|G29|G30|G31|G32|G37) ' test/live_binding_test.dart; echo "exit: $?"
