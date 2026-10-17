#!/usr/bin/env bash
# navigation-api-fixtures: replays the navigation-api@v1 fixtures, as written
# under the repository's hsdd/contract/, against
#   - the stand-in nidana_dart_contracts and nidana_contract_check of
#     ../bus-testing-fixtures/ (copied unchanged);
#   - the stand-in nidana_dart_runtime of ../bus-testing-fixtures/ (copied),
#     with one change marked "navigation-api-fixtures patch" in
#     lib/src/interpreter.dart and lib/src/bus.dart: an activation's
#     connection reaches its reads synchronously, before any later delivery,
#     and the publishes it causes wait for a provider-zone microtask, as
#     bus-api@v1 G22 states (navigation-api@v1 Refinement 8). T10 shows that
#     bus-api@v1's and bus-testing@v1's bindings still pass on it unchanged;
#     T11 shows what the unpatched runtime does;
#   - a stand-in nidana_dart_navigation implementing navigation-api@v1's
#     Interface (packages/nidana_dart_navigation);
#   - a minimal stand-in Flutter router over Navigator
#     (packages/flutter_navigation_standin), bound to the executor suite
#     under testWidgets by standin_bindings/flutter_navigation_standin_test.dart,
#     which this script copies to hsdd/contract/fixture/flutter-binding/
#     behavior/, where flutter-binding@v1's real binding will live.
#
# The repository has no pub workspace yet, so the fixtures and contracts are
# copied into this experiment's own workspace at the same relative paths.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
N=$F/navigation-api
step() { echo; echo "### $*"; }

step "setup: copy the contracts and the fixtures from the repository, resolve"
rm -rf hsdd && mkdir -p $F/flutter-binding/behavior
cp $REPO/hsdd/contract/navigation-api.md $REPO/hsdd/contract/bus-api.md $REPO/hsdd/contract/bus-testing.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/navigation-api $REPO/$F/bus-api $REPO/$F/bus-testing $REPO/$F/topology-dsl $F/
cp standin_bindings/flutter_navigation_standin_test.dart $F/flutter-binding/behavior/
find hsdd/contract/navigation-api.md $N -type f | sort
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version
awk '/^  (meta|matcher|test|test_api|rxdart|clock|lints|flutter_test):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check navigation-api; echo "exit: $?"

step "T2 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $N/surface; echo "exit: $?"

step "T3 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
fvm dart run nidana_contract_check:reject_check $N/reject; echo "exit: $?"

step "T4 reject: the raw diagnostics behind T3, one line each (line severity code)"
for f in $N/reject/*.dart; do
  echo "-- $(basename "$f")"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      for (const d of JSON.parse(s).diagnostics)
        console.log(d.location.range.start.line, d.severity, d.code);
    });'
done

step "T5 the conformance libraries and the bindings analyze clean (warnings included)"
fvm dart analyze --fatal-infos $N/behavior $F/flutter-binding/behavior; echo "exit: $?"

step "T6 behavior: the navigation suite on the stand-in, under dart test from the root"
fvm dart test --reporter expanded $N/behavior/nidana_dart_navigation_test.dart 2>&1 | tail -n 42; echo "exit: ${PIPESTATUS[0]}"

step "T7 behavior: the executor suite on NavigationExecutor over InMemoryRouter, both capabilities, under dart test"
fvm dart test --reporter expanded $N/behavior/in_memory_router_test.dart 2>&1 | tail -n 54; echo "exit: ${PIPESTATUS[0]}"

step "T8 behavior: a guarantee restriction by test-name prefix selects both registrations (--guarantee navigation-api/G20)"
fvm dart test --reporter expanded --name '^G20 ' $N/behavior/in_memory_router_test.dart 2>&1 | tail -n 3; echo "exit: ${PIPESTATUS[0]}"

step "T9 behavior: the executor suite under flutter test and testWidgets, on a stand-in Flutter router and a production-provider bus"
fvm flutter test --no-pub --reporter expanded $F/flutter-binding/behavior/flutter_navigation_standin_test.dart 2>&1 | tail -n 28; echo "exit: ${PIPESTATUS[0]}"

step "T10 the runtime change keeps bus-api@v1's two bindings and bus-testing@v1's binding passing, unchanged"
for b in $F/bus-api/behavior/nidana_dart_runtime_test.dart $F/bus-api/behavior/bus_activation_test.dart $F/bus-testing/behavior/nidana_dart_runtime_test.dart; do
  echo "-- $b"; fvm dart test "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
done

step "T11 what bus-api@v1 G22 and G34 must give: the connection probe, on the changed runtime and on the S11 runtime"
echo "-- changed runtime"
fvm dart run tool/connection_probe.dart
RT=packages/nidana_dart_runtime/lib/src
cp $RT/interpreter.dart $RT/interpreter.dart.patched; cp $RT/bus.dart $RT/bus.dart.patched
cp ../bus-testing-fixtures/$RT/interpreter.dart ../bus-testing-fixtures/$RT/bus.dart $RT/
echo "-- S11 runtime, unchanged (../bus-testing-fixtures/)"
fvm dart run tool/connection_probe.dart
echo "-- the navigation suites on the S11 runtime: the cases that rest on Refinement 8"
for b in $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
  fvm dart test "$b" 2>&1 | grep -E '\[E\]$|Some tests failed|All tests passed' \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
done
echo "-- the Flutter binding on the S11 runtime (pumpWidget runs the connection microtask before start)"
fvm flutter test --no-pub $F/flutter-binding/behavior/flutter_navigation_standin_test.dart 2>&1 | tail -n 1
mv $RT/interpreter.dart.patched $RT/interpreter.dart; mv $RT/bus.dart.patched $RT/bus.dart
echo "restored the changed runtime"

step "T12 probes: names a Flutter page imports, publish and constructor inference, a DeepLink where a resolved intent is expected"
fvm dart analyze --format=json probe | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    for (const d of JSON.parse(s).diagnostics)
      console.log(d.location.file.split("/").pop(), d.location.range.start.line, d.severity, d.code);
  });'
echo "-- the W lines of probe/widening.dart; a line with no diagnostic above compiles (W1, W2, W5, W6)"
grep -n '// W[0-9]' probe/widening.dart

step "T13 probe at run time: a DeepLink published to nav.resolved-intent through bus-api@v1's publish"
fvm dart run tool/publish_runtime_probe.dart

# mutate {runner} {file} {label} {from} {to} {test file}: applies one textual
# defect, runs the suite, prints the failing cases, and restores the file. A
# watchdog kills a run that has not finished after 180 s and says so.
mutate() {
  local runner="$1" file="$2" label="$3" from="$4" to="$5" suite="$6"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  if [ "$runner" = flutter ]; then fvm flutter test --no-pub "$suite" > mutate.log 2>&1 &
  else fvm dart test "$suite" > mutate.log 2>&1 &
  fi
  local pid=$!
  ( trap 'kill "$s" 2>/dev/null; exit 0' TERM; sleep 180 & s=$!; wait "$s"
    if kill -0 "$pid" 2>/dev/null; then echo "TIMED OUT after 180 s" >> mutate.log; pkill -f "$suite"; fi ) &
  local dog=$!
  wait "$pid"
  kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null
  grep -E '\[E\]$|Some tests failed|All tests passed|Error:|TIMED OUT' mutate.log \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
  rm -f mutate.log
  mv "$file.orig" "$file"
}

NAV=packages/nidana_dart_navigation/lib/src/navigation.dart
MEM=packages/nidana_dart_navigation/lib/src/in_memory_router.dart
FLR=packages/flutter_navigation_standin/lib/flutter_navigation_standin.dart
S=$N/behavior/nidana_dart_navigation_test.dart
E=$N/behavior/in_memory_router_test.dart
W=$F/flutter-binding/behavior/flutter_navigation_standin_test.dart

step "T14 the navigation suite is not vacuous: each seeded defect in the stand-in fails the cases of its guarantee"
mutate dart $NAV "route equality ignores the argument type (G5)" "      other.path == path &&
      other.argsType == argsType;" "      other.path == path;" $S
mutate dart $NAV "argsOf ignores the state's route (G5)" "state.route == this ? state.args as A? : null" "state.args is A ? state.args as A? : null" $S
mutate dart $NAV "GoTo equality ignores the arguments (G6)" "other is GoTo && other.route == route && other.args == args;" "other is GoTo && other.route == route;" $S
mutate dart $NAV "the registry accepts one path under two argument types (G7)" "      } else if (seen != r) {" "      } else if (false) {" $S
mutate dart $NAV "route state equality ignores the query parameters (G8)" "      _mapEquals(other.pathParams, pathParams) &&
      _mapEquals(other.queryParams, queryParams);" "      _mapEquals(other.pathParams, pathParams);" $S
mutate dart $NAV "nav.history buffers 10 (G9)" "bufferSize: 20" "bufferSize: 10" $S
mutate dart $NAV "a policy ignores its fallback (G10)" "requirements[route] ?? fallback;" "requirements[route] ?? const PublicAccess();" $S
mutate dart $NAV "resolveDeepLinks calls the resolver twice (G11)" "DeepLink(:final Uri uri) => resolve(uri)," "DeepLink(:final Uri uri) => (resolve(uri), resolve(uri)).\$2," $S
mutate dart $NAV "a pending principal is treated as anonymous (G12)" "PendingPrincipal() => redirects.pending(intent)," "PendingPrincipal() => redirects.unauthenticated(intent)," $S
mutate dart $NAV "RoleAccess requires every role (G12)" "principal.roles.any(roles.contains)" "roles.every(principal.roles.contains)" $S
mutate dart $NAV "the reactive resolver does not guard (G14)" "                  applyAuthGuard(i, p, pol, redirects))" "                  i)" $S
mutate dart $NAV "a static policy is ignored and nav.access-policy read (G13, G14)" "final RouteAccessPolicy? fixed = policy;" "final RouteAccessPolicy? fixed = policy == null ? null : null;" $S
mutate dart $NAV "resultsFor does not filter (G16)" "        .filter((({R result, bool answers}) p) => p.answers)" "        .filter((({R result, bool answers}) p) => true)" $S
mutate dart $NAV "BackTo targets the bottommost entry of its route (G17, G20)" "stack.lastIndexWhere((NavigationEntry e) => e.state.route == route)" "stack.indexWhere((NavigationEntry e) => e.state.route == route)" $S
mutate dart $NAV "Back is planned at the root (G17, G20)" "    Back() => stack.length > 1" "    Back() => stack.isNotEmpty" $S
mutate dart $NAV "synthesized BackTo pops one entry too many (G17, G20)" "  final int pops = stack.length - 1 - at;" "  final int pops = stack.length - at;" $S
mutate dart $MEM "the in-memory router pops its last entry on a platform back (G18, G25)" "    if (_stack.length < 2) return;" "    if (_stack.isEmpty) return;" $S

step "T15 the executor suite is not vacuous: each seeded defect fails the cases of its guarantee, on the VM binding"
mutate dart $MEM "a failed perform keeps the calls before the failing one (G18)" "    final List<NavigationEntry> next = List<NavigationEntry>.of(_stack);
    for (final RouterCall call in calls) {" "    final List<NavigationEntry> next = List<NavigationEntry>.of(_stack);
    final List<NavigationEntry> live = _stack;
    for (final RouterCall call in calls) {
      if (call is PushRoute) live.add(call.entry);" $E
mutate dart $MEM "a perform is confirmed twice (G18)" "    _performed.add(List<RouterCall>.unmodifiable(calls));
    _confirmations.add(RouteConfirmation(stack: _stack, intent: intent));" "    _performed.add(List<RouterCall>.unmodifiable(calls));
    _confirmations.add(RouteConfirmation(stack: _stack, intent: intent));
    _confirmations.add(RouteConfirmation(stack: _stack, intent: intent));" $E
mutate dart $NAV "the executor's source ignores its name (G19)" "      : source = ExecutorSource(name)," "      : source = const ExecutorSource('navigation')," $E
mutate dart $NAV "the executor does not write the initial route (G19)" "      _writer.publish(_current);" "" $E
mutate dart $NAV "late construction is not reported (G19)" "      if (bus.lifecycle == BusLifecycle.running) {" "      if (false) {" $E
mutate dart $NAV "refusals are not reported (G20)" "        _bus.reportDiagnostic(NavigationRefused(" "        (NavigationRefused(" $E
mutate dart $NAV "the executor also performs intents from nav.intent (G20)" "      _intents = bus.observe(NavigationTopics.resolvedIntent).listen(_execute);" "      _intents = bus.observe(NavigationTopics.resolvedIntent).listen(_execute);
      bus.observe(NavigationTopics.intent).listen((NavIntent i) { if (i is ResolvedNavIntent) _execute(i); });" $E
mutate dart $NAV "history is written before the route (G21)" "    _writer.publish(to);
    _publisher.publish(
        NavigationTopics.history,
        RouteTransition(
            from: from, to: to, intent: c.intent, timestamp: _bus.clock.now()));" "    _publisher.publish(
        NavigationTopics.history,
        RouteTransition(
            from: from, to: to, intent: c.intent, timestamp: _bus.clock.now()));
    _writer.publish(to);" $E
mutate dart $NAV "a transition starts from the delivered current value (G21)" "    final RouteState from = _current;" "    final RouteState from = _bus.getCurrentValue(NavigationTopics.currentRoute);" $E
mutate dart $NAV "a transition is stamped with the wall clock (G22)" "timestamp: _bus.clock.now()" "timestamp: DateTime.now()" $E
mutate dart $NAV "dispose keeps the claim (G23)" "    unawaited(_confirmations.cancel());
    _publisher.dispose();" "    unawaited(_confirmations.cancel());" $E
mutate dart $NAV "dispose is not registered with onShutdown (G23)" "      bus.onShutdown(dispose);" "" $E
mutate dart $NAV "a deep link is dropped by the resolver (G24)" "      DeepLink(:final Uri uri) => resolve(uri)," "      DeepLink() => const Back()," $E

step "T16 the executor suite is not vacuous under testWidgets: defects in the stand-in Flutter router and in the executor"
mutate flutter $FLR "the Flutter router confirms the pops of its own performs as platform backs (G18, G20)" "    if (_performing || _stack.length < 2) return;" "    if (_stack.length < 2) return;" $W
mutate flutter $FLR "the Flutter router does not confirm a platform back (G18, G21)" "    _stack.removeLast();
    _controller.add(RouteConfirmation(stack: _stack, intent: const Back()));" "    _stack.removeLast();" $W
mutate flutter $NAV "a transition is stamped with the wall clock (G22)" "timestamp: _bus.clock.now()" "timestamp: DateTime.now()" $W

step "cleanup: remove the copied tree; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd; echo "removed"
