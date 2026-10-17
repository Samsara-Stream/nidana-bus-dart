// Writes the graph documents the scan invocations read, as topic-codegen@v1's
// catalog would: JsonRenderer of TopologyGraph(topologies: buildDefinition()
// of each topology, claims: the claims its app declares). scan-clean's graph
// carries its app's claims, so a scan that read them as well as recognizing
// them would count every claim twice; the other graphs carry none.
// Run from the workspace root: fvm dart run tool/graphs.dart <invocation-dir>
import 'dart:io';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

// Value types named as the fixtures' apps name them, so that '$T' renders the
// same type names the scan reads statically.
final class CartItems {
  const CartItems();
}

final class CartItem {
  const CartItem();
}

final class CheckoutDraft {
  const CheckoutDraft();
}

final class Connectivity {
  const Connectivity();
}

final class RouteState {
  const RouteState();
}

final class SessionState {
  const SessionState();
}

const StateTopic<CartItems> cartItems = StateTopic<CartItems>(name: 'cart.items', initial: CartItems());
const EventTopic<CartItem> cartAdded = EventTopic<CartItem>(name: 'cart.added');
const StateTopic<int> cartBadge = StateTopic<int>(name: 'cart.badge', initial: 0);
const StateTopic<CheckoutDraft> checkoutDraft =
    StateTopic<CheckoutDraft>(name: 'checkout.draft', initial: CheckoutDraft());
const StateTopic<int> checkoutTotal = StateTopic<int>(name: 'checkout.total', initial: 0);
const StateTopic<int> checkoutSummary = StateTopic<int>(name: 'checkout.summary', initial: 0);
const StateTopic<String> checkoutLabel = StateTopic<String>(name: 'checkout.label', initial: '');
const EventTopic<int> checkoutEdits = EventTopic<int>(name: 'checkout.edits');
const StateTopic<Connectivity> connectivity =
    StateTopic<Connectivity>(name: 'network.connectivity', initial: Connectivity());
const StateTopic<RouteState> currentRoute =
    StateTopic<RouteState>(name: 'nav.current-route', initial: RouteState());
const EventTopic<RouteState> restoredRoute = EventTopic<RouteState>(name: 'nav.restored');
const StateTopic<SessionState> sessionState =
    StateTopic<SessionState>(name: 'session.state', initial: SessionState());
const StateTopic<String> bannerText = StateTopic<String>(name: 'banner.text', initial: '');
const StateTopic<int> loopPing = StateTopic<int>(name: 'loop.ping', initial: 0);
const StateTopic<int> loopPong = StateTopic<int>(name: 'loop.pong', initial: 0);
const StateTopic<int> echoValue = StateTopic<int>(name: 'echo.value', initial: 0);
const StateTopic<int> countValue = StateTopic<int>(name: 'count.value', initial: 0);

CartItems addItem(CartItems items, CartItem item) => items;
int badgeOf(CartItems items, Connectivity c) => 0;
int totalOf(CheckoutDraft draft) => 0;
int summarize(CheckoutDraft draft, int total) => total;
int sumEdits(int edit) => edit;
String labelOf(int summary) => '$summary';
String bannerOf(SessionState s) => '';
int next(int v) => v + 1;
int add(int total, int v) => total + v;
RouteState same(RouteState r) => r;

Topology t(String id, Scope scope, void Function(TopologyBuilder b) declare) => topology(id, scope, declare);

final Map<String, List<ShellClaim>> claims = <String, List<ShellClaim>>{
  'scan-clean': <ShellClaim>[
    ShellClaim(source: const ServiceSource('connectivity'), writes: <TopicRef>{connectivity.ref}),
    ShellClaim(source: const PageSource('checkout'), scope: Scope.page, writes: <TopicRef>{checkoutDraft.ref}),
    ShellClaim(source: const ExecutorSource('navigation'), writes: <TopicRef>{currentRoute.ref}),
  ],
};

final Map<String, List<Topology>> graphs = <String, List<Topology>>{
  'scan-clean': <Topology>[
    t('cart-reducer', Scope.application, (TopologyBuilder b) => b.reduceInto(cartItems, b.read(cartAdded), addItem)),
    t('cart-badge', Scope.module,
        (TopologyBuilder b) => b.write(cartBadge, b.combine2(b.read(cartItems), b.read(connectivity), badgeOf))),
    t('checkout-form', Scope.page, (TopologyBuilder b) => b.write(checkoutTotal, b.read(checkoutDraft).map(totalOf))),
  ],
  'scan-writer-conflict': <Topology>[
    t('cart-reducer', Scope.application, (TopologyBuilder b) => b.reduceInto(cartItems, b.read(cartAdded), addItem)),
    t('route-mirror', Scope.application, (TopologyBuilder b) => b.write(currentRoute, b.read(restoredRoute).map(same))),
  ],
  'scan-scope-violation': <Topology>[
    t('checkout-flow', Scope.module,
        (TopologyBuilder b) => b.write(checkoutSummary, b.combine2(b.read(checkoutDraft), b.read(checkoutTotal), summarize))),
    t('draft-form', Scope.page, (TopologyBuilder b) => b.write(checkoutTotal, b.read(checkoutEdits).map(sumEdits))),
    t('summary-page', Scope.page, (TopologyBuilder b) => b.write(checkoutLabel, b.read(checkoutSummary).map(labelOf))),
    t('session-banner', Scope.application, (TopologyBuilder b) => b.write(bannerText, b.read(sessionState).map(bannerOf))),
  ],
  'scan-cycles': <Topology>[
    t('ping', Scope.application, (TopologyBuilder b) => b.write(loopPing, b.read(loopPong).map(next))),
    t('pong', Scope.application, (TopologyBuilder b) => b.write(loopPong, b.read(loopPing).map(next))),
    t('echo', Scope.application, (TopologyBuilder b) => b.write(echoValue, b.read(echoValue).map(next))),
    t('counter', Scope.application, (TopologyBuilder b) => b.write(countValue, b.read(countValue).scan(0, add))),
  ],
};

void main(List<String> args) {
  for (final MapEntry<String, List<Topology>> g in graphs.entries) {
    final TopologyGraph graph = TopologyGraph(
      topologies: <TopologyDefinition>[for (final Topology x in g.value) x.buildDefinition()],
      claims: claims[g.key] ?? const <ShellClaim>[],
    );
    final File out = File('${args.first}/${g.key}/files/topology-graph.json');
    out.writeAsStringSync(const JsonRenderer().render(graph));
    stdout.writeln('${g.key}: ${graph.topologies.length} topologies, ${graph.topics.length} topics; '
        'findings: ${analyzeTopologyGraph(graph).map((TopologyFinding f) => f.runtimeType).join(', ')}');
  }
}
