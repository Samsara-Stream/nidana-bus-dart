#!/usr/bin/env bash
# flutter-binding-fixtures: checks the flutter-binding@v1 fixtures written in
# step S14, and settles the runtime facts OQ-F1 rests on.
#
# Stand-ins, copied from ../bus-api-amendment/: nidana_dart_contracts,
# nidana_contract_check (its structure and reject prototypes),
# nidana_dart_runtime (amended for bus-api@v1's S13 amendment) and
# nidana_dart_navigation (navigation-api@v1), unchanged. New here:
# packages/nidana_dart_runtime_flutter, a stand-in implementing the
# flutter-binding@v1 Interface, with its widget-test library.
#
# The workspace root (fbf_root) is pure Dart and does not depend on Flutter;
# the fixtures are the repository's hsdd/contract/ copied to the same
# relative paths, and both bindings run under `fvm flutter test --no-pub`
# from the root, as ADR-001 item 9 lays it out.
#
# Probes:
#   probe/run_app_attach_test.dart  P1, on the production binding
#   probe/router_facts_test.dart    P2 to P8, Flutter's Navigator
#   gorouter_probe/                 R1 to R5, go_router 18.1.0, in its own
#                                   resolution so it never enters the stand-in
#                                   workspace
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
B=$F/flutter-binding
OWN=$B/behavior/nidana_dart_runtime_flutter_test.dart
NAV=$B/behavior/flutter_navigation_executor_test.dart
SRC=packages/nidana_dart_runtime_flutter/lib/src
step() { echo; echo "### $*"; }

step "setup: copy the contracts and the fixtures from the repository, resolve"
rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/*.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/navigation-api $REPO/$F/flutter-binding $F/
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version
echo "-- the workspace root's own dependencies (no Flutter package):"
sed -n '/^dependencies:/,$p;/^dev_dependencies:/,$p' pubspec.yaml | sort -u

step "P1 runApp attaches the root widget from a Timer (production binding)"
fvm flutter test --no-pub probe/run_app_attach_test.dart 2>&1 | grep -E '^P1|All tests passed|Some tests failed'

step "P2 to P8 Flutter's Navigator: observer timing, initial routes, platform back and route push, unmount, dialogs, maybePop"
fvm flutter test --no-pub probe/router_facts_test.dart 2>&1 | grep -E '^P[0-9]|All tests passed|Some tests failed'

step "R1 go_router 18.1.0 resolves on the pinned SDK, and what it brings"
(cd gorouter_probe && fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"; fvm flutter pub deps --style=compact 2>&1 | sed -n '/^dependencies:/,/^dev dependencies:/p' | grep -E '^- ')
echo "-- transitive packages go_router adds beyond Flutter's own:"
(cd gorouter_probe && fvm flutter pub deps --style=compact 2>&1 | grep -E '^- (cupertino_ui|material_ui|flutter_localizations|intl|logging|flutter_web_plugins) ')

step "R2, R4, R5 go_router: push timing, the platform's initial route, go"
(cd gorouter_probe && fvm flutter test --no-pub test/gorouter_facts_test.dart 2>&1 | grep -E '^R[0-9]|All tests passed|Some tests failed')

step "R3 go_router has no pop-until (a tagged line with no diagnostic compiles)"
(cd gorouter_probe && fvm dart analyze lib/pop_until.dart 2>&1 | grep -E 'error|warning|info' | sed -E 's/ Try .*//'; grep -n '// R3' lib/pop_until.dart)

step "T0 the stand-in adapter is clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages/nidana_dart_runtime_flutter; echo "exit: $?"

step "T1 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check flutter-binding; echo "exit: $?"
echo "-- navigation-api@v1, unchanged by this step"
fvm dart run nidana_contract_check:structure_check navigation-api | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

step "T2 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $B/surface; echo "exit: $?"

step "T3 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
fvm dart run nidana_contract_check:reject_check $B/reject; echo "exit: $?"

step "T4 the conformance library and both bindings analyze clean (warnings included)"
fvm dart analyze --fatal-infos $B/behavior; echo "exit: $?"

step "T5 behavior: this contract's suite, under fvm flutter test from the workspace root"
fvm flutter test --no-pub $OWN 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

step "T6 behavior: navigation-api@v1's executor suite bound to FlutterNavigationExecutor"
fvm flutter test --no-pub $NAV 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

step "T7 a name-prefix filter selects one guarantee's cases (--guarantee flutter-binding/G10)"
fvm flutter test --no-pub --reporter expanded --name '^G10 ' $OWN 2>&1 \
  | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | grep -E '^G|All tests passed|Some tests failed' | sort -u

# report {command...}: runs the command and prints its failing case names.
report() {
  "$@" 2>&1 | grep -E '\[E\]$|Some tests failed|All tests passed|^FAIL' \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
}

# mutate {file} {label} {from} {to} {command...}: applies one textual defect
# to the stand-in, runs the command, and restores the file.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"; shift 4
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  report "$@"
  mv "$file.orig" "$file"
}

own() { fvm flutter test --no-pub $OWN; }
nav() { fvm flutter test --no-pub $NAV; }
both() { fvm flutter test --no-pub $OWN $NAV; }

step "T8 seeded defects in the stand-in fail the cases of the guarantee they break"
mutate $SRC/bus_provider.dart "BusProvider.value owns its bus (G4)" \
  "      : ownsBus = false;" "      : ownsBus = true;" own
mutate $SRC/bus_provider.dart "an owning provider does not shut its bus down when disposed (G4, G17)" \
  "    if (widget.ownsBus) widget.bus.shutdown();" "" own
mutate $SRC/bus_provider.dart "a provider of another bus does not notify its dependents (G3, G5)" \
  "=> !identical(bus, oldWidget.bus);" "=> false;" own
mutate $SRC/topic_builders.dart "the state builder rebuilds for its subscription's first value (G5)" \
  "      _subscription.listen(bus, widget.topic, 1, _changed);" "      _subscription.listen(bus, widget.topic, 0, _changed);" own
mutate $SRC/topic_builders.dart "the state builder keeps its subscription when its topic changes (G5)" \
  "    if (oldWidget.topic != widget.topic) {
      _subscription.listen(_bus!, widget.topic, 1, _changed);" "    if (false) {
      _subscription.listen(_bus!, widget.topic, 1, _changed);" own
mutate $SRC/topic_builders.dart "the replay builder rebuilds for the replay of its buffer (G6)" \
  "_bus!, widget.topic, _bus!.getBufferedValues(widget.topic).length, _changed);" "_bus!, widget.topic, 0, _changed);" own
mutate $SRC/topic_builders.dart "a subscription error reaches the zone (G5)" \
  "      onError: (Object _) => cancel()," "      onError: (Object e) => throw e," own
mutate $SRC/page_scope.dart "a named route keeps its leading slash in the page source (G7)" \
  "(settings?.name ?? '').replaceFirst(RegExp('^/+'), '')" "(settings?.name ?? '')" own
mutate $SRC/page_scope.dart "the page publisher is bound to application scope (G7)" \
  "writes: widget.writes, scope: Scope.page);" "writes: widget.writes, scope: Scope.application);" own
mutate $SRC/page_scope.dart "page topologies are not counted: every unmount deactivates (G8)" \
  "  if (h.holders > 1) {" "  if (false) {" own
mutate $SRC/page_scope.dart "PageScope accepts a topology that is not PAGE-scoped (G8)" \
  "      if (t.scope != Scope.page) {" "      if (false) {" own
mutate $SRC/page_scope.dart "a failed claim leaves the page topologies active (G8)" \
  "      for (final Topology t in _acquired.reversed) {
        _release(bus, t);
      }
      _acquired.clear();
      rethrow;" "      rethrow;" own
mutate $SRC/module_scope.dart "a prefix segment matches any segment it begins (G9)" \
  "      if (p[i] != _prefix[i]) return false;" "      if (!p[i].startsWith(_prefix[i])) return false;" own
mutate $SRC/module_scope.dart "a replace releases the old route before acquiring the new (G10)" \
  "    if (newRoute != null) _acquire(newRoute);
    _release(oldRoute);" "    _release(oldRoute);
    if (newRoute != null) _acquire(newRoute);" own
mutate $SRC/module_scope.dart "a pop releases nothing (G10)" \
  "  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _release(route);" \
  "  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {}" own
mutate $SRC/module_scope.dart "an acquire the bus rejects is thrown into the Navigator (G10)" \
  "      } catch (error, stack) {" "      } on StateError catch (error, stack) {" own
mutate $SRC/module_scope.dart "dispose releases nothing (G10)" \
  "    for (final Route<dynamic> r in List<Route<dynamic>>.of(_held.keys)) {" \
  "    for (final Route<dynamic> r in const <Route<dynamic>>[]) {" own
mutate $SRC/navigation.dart "a perform does not pop the foreign routes above the top entry first (G13)" \
  "        nav.popUntil((Route<dynamic> r) => identical(r, top));" "" own
mutate $SRC/navigation.dart "a pop of any route, a foreign one included, is confirmed as Back (G13)" \
  "    if (_performing || _stack.length < 2 || !identical(route, _routes.last)) return;" \
  "    if (_performing || _stack.length < 2) return;" both
mutate $SRC/navigation.dart "a perform throws while no Navigator hosts the router (G12, G16)" \
  "    final bool hosted = isHosted;" "    final bool hosted = isHosted;
    if (!hosted) throw StateError('no Navigator');" both
mutate $SRC/navigation.dart "the hosting Navigator starts with the bottom entry only (G12, G16)" \
  "<Route<dynamic>>[for (final NavigationEntry e in _stack) _build(e)];" "<Route<dynamic>>[_build(_stack.first)];" both
mutate $SRC/navigation.dart "a route built without its settings is accepted (G11, G13)" \
  "    if (!identical(route.settings, settings)) {" "    if (false) {" own
mutate $SRC/navigation.dart "PopUntilRoute pops to the bottom-most entry of its route (G11)" \
  "          final int target = next.lastIndexWhere((NavigationEntry e) => e.state.route == route);" \
  "          final int target = next.indexWhere((NavigationEntry e) => e.state.route == route);" both
mutate $SRC/navigation.dart "the router does not update its stack after a perform (navigation-api G18; G11)" \
  "    _stack
      ..clear()
      ..addAll(next);
    _routes" "    _routes" both
mutate $SRC/navigation.dart "the executor's default name is navigation (G14)" \
  "    String name = 'flutter-navigation'," "    String name = 'navigation'," own
mutate $SRC/navigation.dart "forwarding is set up before the NavigationExecutor, so a failed construction leaves it (G14)" \
  "    final NavigationExecutor executor = NavigationExecutor(bus, router, name: name);
    final FlutterNavigationExecutor self = FlutterNavigationExecutor._(bus, router, executor);
    if (forwardPlatformRoutes) {" "    if (forwardPlatformRoutes) {
      WidgetsFlutterBinding.ensureInitialized().addObserver(_PlatformRoutes(bus.publisher(ExecutorSource(name))));
    }
    final NavigationExecutor executor = NavigationExecutor(bus, router, name: name);
    final FlutterNavigationExecutor self = FlutterNavigationExecutor._(bus, router, executor);
    if (forwardPlatformRoutes) {" own
mutate $SRC/navigation.dart "dispose leaves the platform route forwarding registered (G14)" \
  "    if (forwarding != null) WidgetsBinding.instance.removeObserver(forwarding);" "" own
mutate $SRC/navigation.dart "the platform's initial route is forwarded even when it is / (G15)" \
  "      if (initialRoute != Navigator.defaultRouteName) {" "      if (true) {" own
mutate $SRC/navigation.dart "a pushed platform route is published but left to WidgetsApp too (G15)" \
  "    return SynchronousFuture<bool>(true);" "    return SynchronousFuture<bool>(false);" own
mutate $SRC/widget_test_bus.dart "WidgetTestBus accepts a virtual provider (G17)" \
  "    if (config.scheduler is VirtualSchedulerProvider) {" "    if (false) {" own
mutate $SRC/widget_test_bus.dart "WidgetTestBus publishes as ServiceSource('widget-test') (G17)" \
  "  static const ServiceSource testSource = ServiceSource('test');" "  static const ServiceSource testSource = ServiceSource('widget-test');" own
mutate $SRC/widget_test_bus.dart "wrap does not own the bus (G17)" \
  "  Widget wrap(Widget child) => BusProvider(bus: bus, child: child);" "  Widget wrap(Widget child) => BusProvider.value(bus: bus, child: child);" own

step "T9 the stand-in restored: both suites pass again"
both 2>&1 | tail -n 1

step "cleanup: remove the copied tree and the Flutter build output; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd build gorouter_probe/build; echo "removed"
