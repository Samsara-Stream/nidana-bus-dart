// navigation-api-v0151 probe P5: re-activating a nav-resolver under
// bus-api@v2 G23, which compares the plan's functions with == besides the
// definitions (Spec §3.9; Guide §6.3 "Name every transformer"). Run against
// each runtime and each navigation stand-in (in-declare, once, cached):
//   fvm dart run probe/reactivation_probe.dart
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const NavRoute<void> _home = NavRoute<void>('p/home');
const NavRoute<int> _detail = NavRoute<int>('p/detail');
const NavRoute<ResolvedNavIntent> _login = NavRoute<ResolvedNavIntent>('p/login');

const StateTopic<bool> _signedIn = StateTopic<bool>(name: 'p.signed-in', initial: true);

AccessPrincipal _principal(bool signedIn) =>
    signedIn ? AuthenticatedPrincipal() : const AnonymousPrincipal();
ResolvedNavIntent _toLogin(ResolvedNavIntent a) => _login.go(a);
ResolvedNavIntent _resolve(Uri uri) => switch (uri.pathSegments) {
      <String>['detail', final String id] => _detail.go(int.parse(id)),
      _ => _home.go(),
    };

final RouteAccessPolicy _policy = RouteAccessPolicy(
    <NavRoute<Object?>, RouteAccessRequirement>{_detail: const AuthenticatedAccess()});

Topology _make(bool reactive) => navResolver<bool>(
      authState: _signedIn,
      principalOf: _principal,
      redirects: const AccessRedirects(unauthenticated: _toLogin, forbidden: _toLogin),
      resolveDeepLink: _resolve,
      policy: reactive ? null : _policy,
    );

String _attempt(TopologyHandle first, Topology Function() second, Bus bus) {
  try {
    final TopologyHandle again = bus.activate(second());
    return identical(again, first) ? 'the active handle' : 'another handle';
  } on TopologyConflict {
    return 'TopologyConflict';
  }
}

void main() {
  for (final bool reactive in <bool>[true, false]) {
    final String form = reactive ? 'reactive' : 'static';
    for (final bool started in <bool>[false, true]) {
      final TestBus bus = TestBus(const BusConfig(devMode: false));
      if (started) bus.start();
      final Topology t = _make(reactive);
      final TopologyHandle h = bus.activate(t);
      final String sameValue = _attempt(h, () => t, bus);
      final String otherCall = _attempt(h, () => _make(reactive), bus);
      print('P5 $form form, ${started ? 'after start()' : 'during bootstrap'}: '
          'the same value again -> $sameValue; another navResolver call of one '
          'configuration -> $otherCall');
    }
  }
}
