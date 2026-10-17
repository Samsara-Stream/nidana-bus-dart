// Conformance library for topology-ir@v1 (ADR-001 item 4): the IR values,
// their projection from a recorded plan, graphs, the analyses, the JSON form
// and the renderers (G2 to G22). Its cases are values; a binding registers
// them with a test runner. It imports neither package:test nor
// package:flutter_test.
//
// The implementation under test is the package's own declarations, which the
// cases call directly: the IR has one implementation by design, so the
// harness carries no factory, only the settle step ADR-001 requires (a no-op,
// since everything here is pure).
//
// The serialized-form cases (ADR-001 item 4) read the files under
// hsdd/contract/fixture/topology-ir/valid/, invalid/ and render/, and the
// schema at hsdd/contract/schema/topology-ir.schema.json, by paths relative to
// the workspace root: the nearest ancestor of the current directory that
// holds hsdd/contract/.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

/// What a binding supplies.
abstract interface class TopologyIrHarness {
  /// Brings the implementation to quiescence; pure values are always there.
  Future<void> settle();
}

// ------------------------------------------------------------ files

const String _schema = 'hsdd/contract/schema/topology-ir.schema.json';
const String _fixtures = 'hsdd/contract/fixture/topology-ir';

Directory _root() {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/hsdd/contract').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('no ancestor of ${Directory.current.path} holds hsdd/contract/');
    }
    dir = parent;
  }
  return dir;
}

String _read(String relative) =>
    File('${_root().path}/$_fixtures/$relative').readAsStringSync();

/// The `.json` files of [set] (valid or invalid), by name without extension,
/// in name order.
List<String> _cases(String set) {
  final List<String> names = <String>[
    for (final FileSystemEntity f
        in Directory('${_root().path}/$_fixtures/$set').listSync())
      if (f is File && f.path.endsWith('.json'))
        f.uri.pathSegments.last.replaceAll('.json', ''),
  ]..sort();
  return names;
}

Object? _json(String set, String name) => jsonDecode(_read('$set/$name.json'));

// ------------------------------------------------------------ data contracts

final class CartItems {
  const CartItems(this.count);
  final int count;
}

final class AuthState {
  const AuthState(this.signedIn);
  final bool signedIn;
}

final class CheckoutUi {
  const CheckoutUi(this.canCheckout);
  final bool canCheckout;
}

final class SubmitOrder {
  const SubmitOrder();
}

final class OrderRequest {
  const OrderRequest(this.items);
  final int items;
}

final class CartEvent {
  const CartEvent(this.delta);
  final int delta;
}

final class Theme {
  const Theme(this.dark);
  final bool dark;
}

final class PaymentSdkState {
  const PaymentSdkState(this.ready);
  final bool ready;
}

final class PaymentResult {
  const PaymentResult(this.ok);
  final bool ok;
}

final class PaymentUi {
  const PaymentUi(this.busy);
  final bool busy;
}

// ------------------------------------------------------------ transformers

Never _called(String what) => throw StateError('recording called $what');

CheckoutUi buildCheckoutUi(CartItems cart, AuthState auth) =>
    _called('buildCheckoutUi');
OrderRequest toOrderRequest(SubmitOrder submit) => _called('toOrderRequest');
CartItems reduceCart(CartItems cart, CartEvent event) => _called('reduceCart');
PaymentUi buildPaymentUi(PaymentSdkState sdk, PaymentResult result) =>
    _called('buildPaymentUi');

int twice(int v) => _called('twice');
bool isPositive(int v) => _called('isPositive');
int add(int a, int b) => _called('add');
int sum(List<int> values) => _called('sum');
int pick(int tap, int count, bool flag) => _called('pick');
Stream<int> ticks(int v) => _called('ticks');
Duration? retryTwice(Object error, int attempt) => _called('retryTwice');
int recoverZero(Object error, StackTrace stackTrace) => _called('recoverZero');
Stream<PipelineValue<int>> passThrough(
  Stream<PipelineValue<int>> values,
  String Function() freshCorrelationId,
) =>
    _called('passThrough');
String describePair(({int previous, int current}) pair) =>
    _called('describePair');
int reduceCount(int state, int event) => _called('reduceCount');
int inc(int v) => _called('inc');
String upper(String v) => _called('upper');
String to$Label(List<Map<String, int>> v) => _called(r'to$Label');

final class Reducers {
  static int reduceTotal(int state, int event) => _called('reduceTotal');
}

final class Labeler {
  const Labeler();
  String label(int v) => _called('label');
}

// ------------------------------------------------------------ topics

abstract final class CheckoutTopics {
  static const StateTopic<CartItems> cartItems =
      StateTopic<CartItems>(name: 'checkout.cart-items', initial: CartItems(0));
  static const StateTopic<CheckoutUi> uiState =
      StateTopic<CheckoutUi>(name: 'checkout.ui-state', initial: CheckoutUi(false));
  static const EventTopic<SubmitOrder> submitOrder =
      EventTopic<SubmitOrder>(name: 'checkout.submit-order');
  static const EventTopic<CartEvent> cartEvents =
      EventTopic<CartEvent>(name: 'checkout.cart-events');
}

abstract final class AuthTopics {
  static const StateTopic<AuthState> state =
      StateTopic<AuthState>(name: 'auth.state', initial: AuthState(false), sensitive: true);
}

abstract final class OrderTopics {
  static const EventTopic<OrderRequest> request =
      EventTopic<OrderRequest>(name: 'order.request');
}

abstract final class SettingsTopics {
  static const EventTopic<Theme> themeRequested =
      EventTopic<Theme>(name: 'settings.theme-requested');
  static const StateTopic<Theme> theme =
      StateTopic<Theme>(name: 'settings.theme', initial: Theme(false));
}

abstract final class PaymentTopics {
  static const StateTopic<PaymentSdkState> sdkState = StateTopic<PaymentSdkState>(
      name: 'payment.sdk-state', initial: PaymentSdkState(false));
  static const StateTopic<PaymentResult> result =
      StateTopic<PaymentResult>(name: 'payment.result', initial: PaymentResult(false));
  static const StateTopic<PaymentUi> uiState =
      StateTopic<PaymentUi>(name: 'payment.ui-state', initial: PaymentUi(false));
}

const StateTopic<String> _currentRoute =
    StateTopic<String>(name: 'nav.current-route', initial: '/');
const StateTopic<int> _everyCount = StateTopic<int>(name: 'every.count', initial: 0);
const EventTopic<int> _everyTaps = EventTopic<int>(name: 'every.taps');
const StateTopic<bool> _everyFlag = StateTopic<bool>(name: 'every.flag', initial: false);
const ReplayTopic<int> _everyLog = ReplayTopic<int>(name: 'every.log', bufferSize: 4);
const EventTopic<int> _everyOut = EventTopic<int>(name: 'every.out');
const EventTopic<int> _everySizes = EventTopic<int>(name: 'every.sizes');
const StateTopic<String> _everyLabel = StateTopic<String>(name: 'every.label', initial: '');
const StateTopic<int> _everyTotal = StateTopic<int>(name: 'every.total', initial: 0);
const EventTopic<String> _everyNames = EventTopic<String>(name: 'every.names');

const EventTopic<int> _loopA = EventTopic<int>(name: 'loop.a');
const EventTopic<int> _loopB = EventTopic<int>(name: 'loop.b');
const StateTopic<int> _echo = StateTopic<int>(name: 'echo.value', initial: 0);
const StateTopic<int> _quiet = StateTopic<int>(name: 'quiet.value', initial: 0);
const StateTopic<int> _settled = StateTopic<int>(name: 'settings.value', initial: 0);
const EventTopic<int> _settleRequested = EventTopic<int>(name: 'settings.requested');
const StateTopic<String> _bannerText = StateTopic<String>(name: 'banner.text', initial: '');
const EventTopic<String> _bannerSource = EventTopic<String>(name: 'banner.source');
const EventTopic<String> _headerTitle = EventTopic<String>(name: 'header.title');
const StateTopic<String> _formDraft = StateTopic<String>(name: 'form.draft', initial: '');
const EventTopic<String> _summary = EventTopic<String>(name: 'summary.text');

const StateTopic<List<Map<String, int>>> _oddTable = StateTopic<List<Map<String, int>>>(
    name: 'odd.table "x" #1', initial: <Map<String, int>>[]);
const EventTopic<({int a, String b})> _oddRecord =
    EventTopic<({int a, String b})>(name: 'odd.<record>');
const StateTopic<int?> _oddNullable = StateTopic<int?>(name: 'odd.café\nline', initial: null);
const EventTopic<String> _oddLabels = EventTopic<String>(name: r'odd.back\slash');

const StateTopic<int> _formsState = StateTopic<int>(name: 'forms.state', initial: 0);
const EventTopic<int> _formsEvent = EventTopic<int>(name: 'forms.event');
const EventTopic<int> _formsOut = EventTopic<int>(name: 'forms.out');
const StateTopic<int> _formsTotal = StateTopic<int>(name: 'forms.total', initial: 0);
const StateTopic<int> _formsClaimed = StateTopic<int>(name: 'forms.claimed', initial: 0);

const StateTopic<String> _authSession =
    StateTopic<String>(name: 'auth.session', initial: '');
const StateTopic<String> _profileDraft =
    StateTopic<String>(name: 'profile.draft', initial: '');
const StateTopic<int> _navDepth = StateTopic<int>(name: 'nav.depth', initial: 0);
const StateTopic<bool> _wizardOpen = StateTopic<bool>(name: 'wizard.open', initial: false);

// ------------------------------------------------------------ samples

/// Spec §6.1 and §6.2's checkout topology in class form.
final class CheckoutFlow extends Topology {
  const CheckoutFlow();

  @override
  String get topologyId => 'checkout-flow';

  @override
  Scope get scope => Scope.module;

  @override
  void declare(TopologyBuilder b) {
    b.write(
      CheckoutTopics.uiState,
      b.combine2(b.read(CheckoutTopics.cartItems), b.read(AuthTopics.state),
          buildCheckoutUi),
    );
    b.write(OrderTopics.request,
        b.read(CheckoutTopics.submitOrder).map(toOrderRequest));
  }
}

final Topology _cartReducer = topology(
  'checkout-cart-reducer',
  Scope.module,
  (TopologyBuilder b) =>
      b.reduceInto(CheckoutTopics.cartItems, b.read(CheckoutTopics.cartEvents), reduceCart),
);

/// Spec §3.11's last-write-wins owner.
final Topology _themeOwner = topology(
  'theme-owner',
  Scope.application,
  (TopologyBuilder b) =>
      b.write(SettingsTopics.theme, b.read(SettingsTopics.themeRequested)),
);

/// Spec §7.1's payment flow, reading two topics a service claims.
final Topology _paymentFlow = topology(
  'payment-flow',
  Scope.application,
  (TopologyBuilder b) => b.write(
    PaymentTopics.uiState,
    b.combine2(b.read(PaymentTopics.sdkState), b.read(PaymentTopics.result),
        buildPaymentUi),
  ),
);

/// Every combinator once, every input form, a retry, an anonymous closure,
/// durations of zero, of whole seconds and of sub-millisecond precision, a
/// write of a read, and self-reads mediated by reduceInto.
final Topology _everyCombinator = topology(
  'every-combinator',
  Scope.page,
  (TopologyBuilder b) {
    final TopicStream<int> count = b.read(_everyCount);
    final TopicStream<int> taps = b.read(_everyTaps);
    final TopicStream<bool> flag = b.read(_everyFlag, dedup: Dedup.none);
    final TopicStream<int> log = b.read(_everyLog);
    final TopicStream<int> mapped = count.map(twice);
    final TopicStream<int> filtered = mapped.filter(isPositive);
    final TopicStream<int> c2 = b.combine2(count, taps, add);
    final TopicStream<int> cAll = b.combineAll(<TopicStream<int>>[c2, filtered], sum);
    final TopicStream<int> picked = taps.withLatestFrom2(count, flag, pick);
    final TopicStream<int> merged = b.merge(<TopicStream<int>>[picked, cAll, log]);
    final TopicStream<int> switched = merged.switchMap(ticks, retry: retryTwice);
    final TopicStream<int> scanned = switched.scan(0, add);
    final TopicStream<({int previous, int current})> pairs = scanned.pairwise();
    final TopicStream<int> distinct = scanned.distinctUntilChanged();
    final TopicStream<int> debounced = distinct.debounce(const Duration(milliseconds: 300));
    final TopicStream<int> throttled = debounced.throttle(const Duration(seconds: 1));
    final TopicStream<int> delayed = throttled.delay(Duration.zero);
    final TopicStream<int> sampled = delayed.sample(const Duration(microseconds: 1500));
    final TopicStream<List<int>> buffered = sampled.buffer(const Duration(seconds: 2));
    final TopicStream<int> timed = sampled.timeout(const Duration(seconds: 5));
    final TopicStream<int> caught = timed.catchError(recoverZero);
    final TopicStream<int> raw = caught.rawEngine(passThrough);
    b.write(_everyOut, raw);
    b.write(_everySizes, buffered.map((List<int> xs) => xs.length));
    b.write(_everyLabel, pairs.map(describePair));
    b.write(_everyNames, count.map(const Labeler().label));
    b.reduceInto(_everyCount, taps, reduceCount);
    b.reduceInto(_everyTotal, b.merge(<TopicStream<int>>[b.read(_everyTotal), taps]),
        Reducers.reduceTotal);
    b.write(_everyLog, b.read(_everyTaps));
  },
);

/// Each analysis finds something.
List<Topology> _findingTopologies() => <Topology>[
      topology('ping', Scope.application,
          (TopologyBuilder b) => b.write(_loopB, b.read(_loopA).map(inc))),
      topology('pong', Scope.application,
          (TopologyBuilder b) => b.write(_loopA, b.read(_loopB).map(inc))),
      topology('echo', Scope.module,
          (TopologyBuilder b) => b.write(_echo, b.read(_echo).map(inc))),
      topology('quiet', Scope.module, (TopologyBuilder b) {
        final TopicStream<int> v = b.read(_quiet);
        b.write(_quiet,
            b.merge(<TopicStream<int>>[v.debounce(Duration.zero), v.delay(const Duration(milliseconds: 10))]));
      }),
      topology('settings-owner', Scope.module,
          (TopologyBuilder b) => b.write(_settled, b.read(_settleRequested))),
      topology('banner', Scope.page,
          (TopologyBuilder b) => b.write(_bannerText, b.read(_bannerSource))),
      topology('header', Scope.application,
          (TopologyBuilder b) => b.write(_headerTitle, b.read(_bannerText).map(upper))),
      topology('summary', Scope.module,
          (TopologyBuilder b) => b.write(_summary, b.read(_formDraft).map(upper))),
    ];

/// One edge of each form the schema distinguishes, small enough to mutate:
/// the base of the invalid/ edge cases.
final Topology _forms = topology('forms', Scope.page, (TopologyBuilder b) {
  final TopicStream<int> state = b.read(_formsState, dedup: Dedup.none);
  final TopicStream<int> event = b.read(_formsEvent);
  final TopicStream<int> mapped = event.map(inc);
  final TopicStream<int> latest = mapped.withLatestFrom(state, add);
  final TopicStream<int> merged = b.merge(<TopicStream<int>>[latest, event]);
  b.write(_formsOut, merged.debounce(const Duration(milliseconds: 5)));
  b.reduceInto(_formsTotal, event, reduceCount);
});

/// Text the renderers escape; the escaping sample adds a topology with no
/// edges.
final Topology _escaping = topology(
  'odd "quoted" #1 <tag> back\\slash café',
  Scope.module,
  (TopologyBuilder b) {
    b.write(_oddLabels, b.read(_oddTable).map(to$Label));
    b.write(_oddRecord, b.read(_oddRecord).filter((({int a, String b}) r) => r.a > 0));
    b.write(_oddNullable, b.read(_oddNullable, dedup: Dedup.equality));
  },
);

/// The sample graphs: one per file under valid/ and per pair under render/.
final Map<String, TopologyGraph Function()> topologyIrSamples =
    <String, TopologyGraph Function()>{
  'checkout': () => TopologyGraph(
        topologies: <TopologyDefinition>[
          const CheckoutFlow().buildDefinition(),
          _cartReducer.buildDefinition(),
          _themeOwner.buildDefinition(),
          _paymentFlow.buildDefinition(),
        ],
        claims: <ShellClaim>[
          ShellClaim(
              source: const ServiceSource('payment-sdk'),
              writes: <TopicRef>{PaymentTopics.sdkState.ref, PaymentTopics.result.ref}),
          ShellClaim(
              source: const ExecutorSource('flutter-navigation'),
              writes: <TopicRef>{_currentRoute.ref}),
        ],
      ),
  'claims_only': () => TopologyGraph(claims: <ShellClaim>[
        ShellClaim(source: const ServiceSource('auth'), writes: <TopicRef>{_authSession.ref}),
        ShellClaim(
            source: const PageSource('settings/profile'),
            scope: Scope.page,
            writes: <TopicRef>{_profileDraft.ref}),
        ShellClaim(
            source: const ExecutorSource('flutter-navigation'),
            writes: <TopicRef>{_navDepth.ref, _currentRoute.ref}),
        ShellClaim(
            source: const ExecutorSource('wizard'),
            scope: Scope.module,
            writes: <TopicRef>{_wizardOpen.ref}),
        ShellClaim(source: const ServiceSource('auth'), writes: <TopicRef>{_authSession.ref}),
      ]),
  'empty': () => TopologyGraph(),
  'escaping': () => TopologyGraph(
        topologies: <TopologyDefinition>[
          _escaping.buildDefinition(),
          topology('idle', Scope.page, (TopologyBuilder b) {}).buildDefinition(),
        ],
        claims: <ShellClaim>[
          ShellClaim(
              source: const PageSource('checkout/cart?step="2"'),
              scope: Scope.module,
              writes: <TopicRef>{_oddTable.ref}),
        ],
      ),
  'every_combinator': () => _everyCombinator.buildDefinition().toGraph(),
  'forms': () => TopologyGraph(
        topologies: <TopologyDefinition>[_forms.buildDefinition()],
        claims: <ShellClaim>[
          ShellClaim(source: const ServiceSource('forms'), writes: <TopicRef>{_formsClaimed.ref}),
        ],
      ),
  'findings': () => TopologyGraph(
        topologies: <TopologyDefinition>[
          for (final Topology t in _findingTopologies()) t.buildDefinition(),
        ],
        claims: <ShellClaim>[
          ShellClaim(source: const ServiceSource('settings-sync'), writes: <TopicRef>{_settled.ref}),
          ShellClaim(
              source: const PageSource('checkout/cart'),
              scope: Scope.page,
              writes: <TopicRef>{_formDraft.ref}),
        ],
      ),
};

// ------------------------------------------------------------ helpers

TopicRef _ref(String name, [TopicVariant variant = TopicVariant.event, String type = 'int']) =>
    TopicRef(name: name, variant: variant, typeName: type);

TopicRef _state(String name, [String type = 'int']) => _ref(name, TopicVariant.state, type);

final FunctionRef _f = FunctionRef.named('f');

TransformEdge _map(EdgeInput input) =>
    TransformEdge.stage(CombinatorKind.map, <EdgeInput>[input], transformer: _f);

TopologyDefinition _def(String id, Scope scope, List<TransformEdge> transforms) =>
    TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);

/// A topology that reads [reads] and writes each of [writes] (plain writes).
TopologyDefinition _rw(String id, Scope scope, List<TopicRef> reads, List<TopicRef> writes) =>
    _def(id, scope, <TransformEdge>[
      TransformEdge.stage(CombinatorKind.merge,
          <EdgeInput>[for (final TopicRef r in reads) TopicInput(r)]),
      for (final TopicRef w in writes) TransformEdge.write(w, const StageInput(0)),
    ]);

const List<String> _kindNames = <String>[
  'map', 'filter', 'combine', 'withLatestFrom', 'merge', 'switchMap', 'scan', //
  'pairwise', 'distinctUntilChanged', 'debounce', 'throttle', 'delay', //
  'sample', 'buffer', 'timeout', 'catchError', 'rawEngine', 'reduceInto',
];

Matcher _throwsFormat = throwsA(isA<FormatException>());

/// [document] with [edit] applied to a deep copy.
Object? _edited(Object? document, void Function(Map<String, Object?> doc) edit) {
  final Map<String, Object?> copy =
      jsonDecode(jsonEncode(document)) as Map<String, Object?>;
  edit(copy);
  return copy;
}

Map<String, Object?> _topology(Map<String, Object?> doc, int i) =>
    (doc['topologies']! as List<Object?>)[i]! as Map<String, Object?>;

List<Object?> _transforms(Map<String, Object?> doc, int i) =>
    _topology(doc, i)['transforms']! as List<Object?>;

// ------------------------------------------------------------ cases

final List<ConformanceCase<TopologyIrHarness>> topologyIrConformance =
    <ConformanceCase<TopologyIrHarness>>[
  // ------------------------------------------------------------ G2
  (
    name: 'G2 CombinatorKind has exactly the eighteen values, in order',
    body: (TopologyIrHarness h) async {
      await h.settle();
      expect(<String>[for (final CombinatorKind k in CombinatorKind.values) k.name], _kindNames);
    },
  ),
  // ------------------------------------------------------------ G3
  (
    name: 'G3 every collection the IR, graphs, claims and findings expose is unmodifiable',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = topologyIrSamples['findings']!();
      final TopologyDefinition d = g.topologies.first;
      final List<TopologyFinding> findings = analyzeTopologyGraph(g);
      await h.settle();
      expect(() => d.transforms.add(d.transforms.first), throwsUnsupportedError);
      expect(() => d.transforms.first.inputs.clear(), throwsUnsupportedError);
      expect(() => d.reads.clear(), throwsUnsupportedError);
      expect(() => d.writes.add(_ref('x')), throwsUnsupportedError);
      expect(() => g.topologies.clear(), throwsUnsupportedError);
      expect(() => g.claims.clear(), throwsUnsupportedError);
      expect(() => g.topics.clear(), throwsUnsupportedError);
      expect(() => g.claims.first.writes.clear(), throwsUnsupportedError);
      expect(() => findings.clear(), throwsUnsupportedError);
      for (final TopologyFinding f in findings) {
        switch (f) {
          case TopologyCycle(:final List<String> topologyIds, :final List<TopicRef> topics):
            expect(() => topologyIds.clear(), throwsUnsupportedError);
            expect(() => topics.clear(), throwsUnsupportedError);
          case SelfReference(:final List<int> edges):
            expect(() => edges.clear(), throwsUnsupportedError);
          case WriterConflict(:final List<MessageSource> writers):
            expect(() => writers.clear(), throwsUnsupportedError);
          case ScopeViolation():
            break;
        }
      }
    },
  ),
  (
    name: 'G3 the IR copies the lists it is given; later changes to them do not reach it',
    body: (TopologyIrHarness h) async {
      final List<EdgeInput> inputs = <EdgeInput>[TopicInput(_ref('a'))];
      final TransformEdge e = TransformEdge.stage(CombinatorKind.merge, inputs);
      final List<TransformEdge> transforms = <TransformEdge>[
        e,
        TransformEdge.write(_ref('b'), const StageInput(0)),
      ];
      final TopologyDefinition d = _def('copy', Scope.page, transforms);
      final List<TopologyDefinition> topologies = <TopologyDefinition>[d];
      final Set<TopicRef> claimed = <TopicRef>{_state('c')};
      final TopologyGraph g = TopologyGraph(
          topologies: topologies,
          claims: <ShellClaim>[ShellClaim(source: const ServiceSource('s'), writes: claimed)]);
      inputs.add(TopicInput(_ref('z')));
      transforms.clear();
      topologies.clear();
      claimed.add(_state('d'));
      await h.settle();
      expect(e.inputs, hasLength(1));
      expect(d.transforms, hasLength(2));
      expect(g.topologies, <TopologyDefinition>[d]);
      expect(g.claims.single.writes, <TopicRef>{_state('c')});
    },
  ),
  // ------------------------------------------------------------ G4
  (
    name: 'G4 every definition a plan projects to is pure data: it encodes to JSON and decodes back equal',
    body: (TopologyIrHarness h) async {
      final List<TopologyDefinition> all = <TopologyDefinition>[
        for (final TopologyGraph Function() s in topologyIrSamples.values) ...s().topologies,
      ];
      await h.settle();
      expect(all, isNotEmpty);
      for (final TopologyDefinition d in all) {
        final String text = jsonEncode(encodeTopologyDefinition(d));
        expect(decodeTopologyDefinition(jsonDecode(text)), d);
      }
    },
  ),
  // ------------------------------------------------------------ G5
  (
    name: 'G5 a stage edge takes the input count its combinator allows',
    body: (TopologyIrHarness h) async {
      final List<EdgeInput> one = <EdgeInput>[TopicInput(_ref('a'))];
      final List<EdgeInput> two = <EdgeInput>[TopicInput(_ref('a')), TopicInput(_ref('b'))];
      final List<EdgeInput> five = <EdgeInput>[
        for (final String n in <String>['a', 'b', 'c', 'd', 'e']) TopicInput(_ref(n)),
      ];
      await h.settle();
      expect(() => TransformEdge.stage(CombinatorKind.map, two, transformer: _f), throwsArgumentError);
      expect(() => TransformEdge.stage(CombinatorKind.map, const <EdgeInput>[], transformer: _f),
          throwsArgumentError);
      expect(() => TransformEdge.stage(CombinatorKind.merge, const <EdgeInput>[]), throwsArgumentError);
      expect(() => TransformEdge.stage(CombinatorKind.combine, const <EdgeInput>[], transformer: _f),
          throwsArgumentError);
      expect(() => TransformEdge.stage(CombinatorKind.withLatestFrom, one, transformer: _f),
          throwsArgumentError);
      expect(() => TransformEdge.stage(CombinatorKind.withLatestFrom, five, transformer: _f),
          throwsArgumentError);
      expect(TransformEdge.stage(CombinatorKind.combine, one, transformer: _f).inputs, one);
      expect(TransformEdge.stage(CombinatorKind.merge, five).inputs, five);
      expect(TransformEdge.stage(CombinatorKind.withLatestFrom, five.sublist(0, 4), transformer: _f).inputs,
          hasLength(4));
      expect(TransformEdge.stage(CombinatorKind.withLatestFrom, two, transformer: _f).inputs, two);
    },
  ),
  (
    name: 'G5 a stage edge carries a transformer, a duration and a retry exactly where its combinator holds one',
    body: (TopologyIrHarness h) async {
      final List<EdgeInput> one = <EdgeInput>[TopicInput(_ref('a'))];
      const Duration d = Duration(milliseconds: 5);
      await h.settle();
      for (final CombinatorKind k in <CombinatorKind>[
        CombinatorKind.map,
        CombinatorKind.filter,
        CombinatorKind.switchMap,
        CombinatorKind.scan,
        CombinatorKind.catchError,
        CombinatorKind.rawEngine,
        CombinatorKind.combine,
      ]) {
        expect(() => TransformEdge.stage(k, one), throwsArgumentError, reason: k.name);
        expect(TransformEdge.stage(k, one, transformer: _f).transformer, _f, reason: k.name);
        expect(() => TransformEdge.stage(k, one, transformer: _f, duration: d), throwsArgumentError,
            reason: k.name);
      }
      for (final CombinatorKind k in <CombinatorKind>[
        CombinatorKind.debounce,
        CombinatorKind.throttle,
        CombinatorKind.delay,
        CombinatorKind.sample,
        CombinatorKind.buffer,
        CombinatorKind.timeout,
      ]) {
        expect(() => TransformEdge.stage(k, one), throwsArgumentError, reason: k.name);
        expect(() => TransformEdge.stage(k, one, duration: const Duration(microseconds: -1)),
            throwsArgumentError, reason: k.name);
        expect(() => TransformEdge.stage(k, one, duration: d, transformer: _f), throwsArgumentError,
            reason: k.name);
        expect(TransformEdge.stage(k, one, duration: Duration.zero).duration, Duration.zero,
            reason: k.name);
      }
      for (final CombinatorKind k in <CombinatorKind>[
        CombinatorKind.merge,
        CombinatorKind.pairwise,
        CombinatorKind.distinctUntilChanged,
      ]) {
        expect(() => TransformEdge.stage(k, one, transformer: _f), throwsArgumentError, reason: k.name);
        expect(() => TransformEdge.stage(k, one, duration: d), throwsArgumentError, reason: k.name);
        expect(TransformEdge.stage(k, one).transformer, isNull, reason: k.name);
      }
      expect(TransformEdge.stage(CombinatorKind.switchMap, one, transformer: _f, retry: _f).retry, _f);
      expect(() => TransformEdge.stage(CombinatorKind.map, one, transformer: _f, retry: _f),
          throwsArgumentError);
      expect(() => TransformEdge.stage(CombinatorKind.reduceInto, one, transformer: _f),
          throwsArgumentError);
    },
  ),
  (
    name: 'G5 a write and a reduceInto are sink edges; a reduceInto targets a state topic',
    body: (TopologyIrHarness h) async {
      final TransformEdge w = TransformEdge.write(_ref('out'), const StageInput(0));
      final TransformEdge r =
          TransformEdge.reduceInto(_state('total'), TopicInput(_ref('taps')), _f);
      final TransformEdge s = _map(TopicInput(_ref('a')));
      await h.settle();
      expect(w.combinator, isNull);
      expect(w.output, _ref('out'));
      expect(w.inputs, <EdgeInput>[const StageInput(0)]);
      expect(w.transformer, isNull);
      expect(w.duration, isNull);
      expect(w.retry, isNull);
      expect(w.isSink, isTrue);
      expect(r.combinator, CombinatorKind.reduceInto);
      expect(r.output, _state('total'));
      expect(r.transformer, _f);
      expect(r.isSink, isTrue);
      expect(s.output, isNull);
      expect(s.isSink, isFalse);
      expect(() => TransformEdge.reduceInto(_ref('total'), TopicInput(_ref('taps')), _f),
          throwsArgumentError);
      expect(() => TransformEdge.reduceInto(_ref('total', TopicVariant.replay), TopicInput(_ref('t')), _f),
          throwsArgumentError);
    },
  ),
  // ------------------------------------------------------------ G6
  (
    name: 'G6 a definition derives reads and writes from its edges, in canonical order',
    body: (TopologyIrHarness h) async {
      final TopologyDefinition d = _def('derive', Scope.module, <TransformEdge>[
        TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
          TopicInput(_ref('m.b')),
          TopicInput(_state('m.a', 'String'), dedup: Dedup.none),
          TopicInput(_ref('m.b')),
          TopicInput(_state('m.a', 'int')),
          TopicInput(_ref('m.a', TopicVariant.event, 'int')),
        ]),
        TransformEdge.write(_ref('w.z'), const StageInput(0)),
        TransformEdge.write(_ref('w.y'), TopicInput(_ref('m.c'))),
        TransformEdge.reduceInto(_state('w.x'), const StageInput(0), _f),
      ]);
      await h.settle();
      expect(d.reads.toList(), <TopicRef>[
        _state('m.a', 'String'),
        _state('m.a', 'int'),
        _ref('m.a', TopicVariant.event, 'int'),
        _ref('m.b'),
        _ref('m.c'),
      ]);
      expect(d.writes.toList(), <TopicRef>[_state('w.x'), _ref('w.y'), _ref('w.z')]);
      expect(_def('none', Scope.page, const <TransformEdge>[]).reads, isEmpty);
    },
  ),
  (
    name: 'G6 a definition rejects an empty id and ill-formed edges',
    body: (TopologyIrHarness h) async {
      final TransformEdge stage = _map(TopicInput(_ref('a')));
      await h.settle();
      expect(() => _def('', Scope.page, const <TransformEdge>[]), throwsArgumentError);
      expect(
          () => _def('forward', Scope.page, <TransformEdge>[
                _map(const StageInput(1)),
                _map(TopicInput(_ref('a'))),
                TransformEdge.write(_ref('b'), const StageInput(0)),
              ]),
          throwsArgumentError);
      expect(
          () => _def('itself', Scope.page, <TransformEdge>[
                _map(const StageInput(0)),
                TransformEdge.write(_ref('b'), const StageInput(0)),
              ]),
          throwsArgumentError);
      expect(
          () => _def('beyond', Scope.page, <TransformEdge>[
                TransformEdge.write(_ref('b'), const StageInput(5)),
              ]),
          throwsArgumentError);
      expect(
          () => _def('stage-after-sink', Scope.page, <TransformEdge>[
                stage,
                TransformEdge.write(_ref('b'), const StageInput(0)),
                _map(TopicInput(_ref('c'))),
                TransformEdge.write(_ref('d'), const StageInput(2)),
              ]),
          throwsArgumentError);
      expect(
          () => _def('consumes-a-sink', Scope.page, <TransformEdge>[
                TransformEdge.write(_ref('b'), TopicInput(_ref('a'))),
                TransformEdge.write(_ref('c'), const StageInput(0)),
              ]),
          throwsArgumentError);
      expect(
          () => _def('unconsumed', Scope.page, <TransformEdge>[
                stage,
                _map(TopicInput(_ref('c'))),
                TransformEdge.write(_ref('b'), const StageInput(0)),
              ]),
          throwsArgumentError);
      expect(
          () => _def('two-state-sinks', Scope.page, <TransformEdge>[
                TransformEdge.write(_state('s'), TopicInput(_ref('a'))),
                TransformEdge.reduceInto(_state('s'), TopicInput(_ref('b')), _f),
              ]),
          throwsArgumentError);
      expect(
          _def('two-event-sinks', Scope.page, <TransformEdge>[
            TransformEdge.write(_ref('e'), TopicInput(_ref('a'))),
            TransformEdge.write(_ref('e'), TopicInput(_ref('b'))),
          ]).writes,
          <TopicRef>{_ref('e')});
    },
  ),
  // ------------------------------------------------------------ G7
  (
    name: 'G7 IR values are equal, with equal hash codes, exactly when their fields are',
    body: (TopologyIrHarness h) async {
      TopologyDefinition make({String id = 'eq', Scope scope = Scope.page, String fn = 'f'}) =>
          _def(id, scope, <TransformEdge>[
            TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[TopicInput(_state('a'), dedup: Dedup.none)],
                duration: const Duration(milliseconds: 1)),
            TransformEdge.stage(CombinatorKind.map, <EdgeInput>[const StageInput(0)],
                transformer: FunctionRef.named(fn)),
            TransformEdge.write(_ref('b'), const StageInput(1)),
          ]);
      await h.settle();
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(id: 'other'), isNot(make()));
      expect(make(scope: Scope.module), isNot(make()));
      expect(make(fn: 'g'), isNot(make()));
      expect(FunctionRef.named('f'), FunctionRef.named('f'));
      expect(FunctionRef.named('f').hashCode, FunctionRef.named('f').hashCode);
      expect(const FunctionRef.anonymous(), const FunctionRef.anonymous());
      expect(FunctionRef.named('f'), isNot(const FunctionRef.anonymous()));
      expect(TopicInput(_state('a')), TopicInput(_state('a')));
      expect(TopicInput(_state('a')), isNot(TopicInput(_state('a'), dedup: Dedup.equality)));
      expect(const StageInput(2), const StageInput(2));
      expect(const StageInput(2), isNot(const StageInput(3)));
      expect(_map(TopicInput(_ref('a'))), _map(TopicInput(_ref('a'))));
      expect(_map(TopicInput(_ref('a'))).hashCode, _map(TopicInput(_ref('a'))).hashCode);
      expect(_map(TopicInput(_ref('a'))), isNot(_map(TopicInput(_ref('b')))));
      expect(
          TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[TopicInput(_ref('a'))],
              duration: Duration.zero),
          isNot(TransformEdge.stage(CombinatorKind.delay, <EdgeInput>[TopicInput(_ref('a'))],
              duration: Duration.zero)));
      expect(
          TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[TopicInput(_ref('a'))],
              duration: const Duration(milliseconds: 1)),
          isNot(TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[TopicInput(_ref('a'))],
              duration: const Duration(milliseconds: 2))));
      expect(
          TransformEdge.stage(CombinatorKind.switchMap, <EdgeInput>[TopicInput(_ref('a'))],
              transformer: _f, retry: _f),
          isNot(TransformEdge.stage(CombinatorKind.switchMap, <EdgeInput>[TopicInput(_ref('a'))],
              transformer: _f)));
      expect(TransformEdge.write(_ref('x'), TopicInput(_ref('a'))),
          isNot(TransformEdge.write(_ref('y'), TopicInput(_ref('a')))));
    },
  ),
  (
    name: 'G7 graphs, claims, declarations and findings are equal, with equal hash codes, exactly when their fields are',
    body: (TopologyIrHarness h) async {
      final TopologyGraph a = topologyIrSamples['findings']!();
      final TopologyGraph b = topologyIrSamples['findings']!();
      final TopologyGraph reversed = TopologyGraph(
          topologies: a.topologies.reversed, claims: a.claims.reversed);
      await h.settle();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(reversed, a);
      expect(TopologyGraph(topologies: a.topologies), isNot(a));
      expect(analyzeTopologyGraph(a), analyzeTopologyGraph(b));
      expect(ShellClaim(source: const ServiceSource('s'), writes: <TopicRef>{_state('a'), _state('b')}),
          ShellClaim(source: const ServiceSource('s'), writes: <TopicRef>{_state('b'), _state('a')}));
      expect(ShellClaim(source: const ServiceSource('s'), writes: <TopicRef>{_state('a')}),
          isNot(ShellClaim(source: const ServiceSource('s'), scope: Scope.page, writes: <TopicRef>{_state('a')})));
      expect(TopicDeclaration(topic: _ref('a'), site: 'x'), TopicDeclaration(topic: _ref('a'), site: 'x'));
      expect(TopicDeclaration(topic: _ref('a'), site: 'x'), isNot(TopicDeclaration(topic: _ref('a'), site: 'y')));
      expect(
          ScopeViolation(
              topic: _state('t'),
              owner: const TopologySource('o'),
              ownerScope: Scope.page,
              readerId: 'r',
              readerScope: Scope.module),
          isNot(ScopeViolation(
              topic: _state('t'),
              owner: const TopologySource('o'),
              ownerScope: Scope.page,
              readerId: 'r',
              readerScope: Scope.application)));
      expect(WriterConflict(topic: _state('t'), writers: const <MessageSource>[TopologySource('a')]).hashCode,
          WriterConflict(topic: _state('t'), writers: const <MessageSource>[TopologySource('a')]).hashCode);
    },
  ),
  // ------------------------------------------------------------ G8
  (
    name: 'G8 a plan projects one stage edge per non-read stage, in stage order, then one sink edge per sink, in sink order',
    body: (TopologyIrHarness h) async {
      final TopologyDefinition d = const CheckoutFlow().buildDefinition();
      await h.settle();
      expect(d, _def('checkout-flow', Scope.module, <TransformEdge>[
        TransformEdge.stage(CombinatorKind.combine, <EdgeInput>[
          TopicInput(CheckoutTopics.cartItems.ref),
          TopicInput(AuthTopics.state.ref),
        ], transformer: FunctionRef.named('buildCheckoutUi')),
        TransformEdge.stage(CombinatorKind.map, <EdgeInput>[TopicInput(CheckoutTopics.submitOrder.ref)],
            transformer: FunctionRef.named('toOrderRequest')),
        TransformEdge.write(CheckoutTopics.uiState.ref, const StageInput(0)),
        TransformEdge.write(OrderTopics.request.ref, const StageInput(1)),
      ]));
    },
  ),
  (
    name: 'G8 every combinator projects to its kind, its inputs in input order, its function, duration and retry',
    body: (TopologyIrHarness h) async {
      final TopologyDefinition d = _everyCombinator.buildDefinition();
      FunctionRef n(String name) => FunctionRef.named(name);
      TopicInput t(Topic<Object?> topic, {Dedup? dedup}) => TopicInput(topic.ref, dedup: dedup);
      TransformEdge one(CombinatorKind k, EdgeInput i, {FunctionRef? f, Duration? d}) =>
          TransformEdge.stage(k, <EdgeInput>[i], transformer: f, duration: d);
      await h.settle();
      expect(d.transforms, <TransformEdge>[
        one(CombinatorKind.map, t(_everyCount), f: n('twice')), // 0
        one(CombinatorKind.filter, const StageInput(0), f: n('isPositive')), // 1
        TransformEdge.stage(CombinatorKind.combine, <EdgeInput>[t(_everyCount), t(_everyTaps)],
            transformer: n('add')), // 2
        TransformEdge.stage(CombinatorKind.combine, const <EdgeInput>[StageInput(2), StageInput(1)],
            transformer: n('sum')), // 3
        TransformEdge.stage(CombinatorKind.withLatestFrom,
            <EdgeInput>[t(_everyTaps), t(_everyCount), t(_everyFlag, dedup: Dedup.none)],
            transformer: n('pick')), // 4
        TransformEdge.stage(CombinatorKind.merge,
            <EdgeInput>[const StageInput(4), const StageInput(3), t(_everyLog)]), // 5
        TransformEdge.stage(CombinatorKind.switchMap, const <EdgeInput>[StageInput(5)],
            transformer: n('ticks'), retry: n('retryTwice')), // 6
        one(CombinatorKind.scan, const StageInput(6), f: n('add')), // 7
        one(CombinatorKind.pairwise, const StageInput(7)), // 8
        one(CombinatorKind.distinctUntilChanged, const StageInput(7)), // 9
        one(CombinatorKind.debounce, const StageInput(9), d: const Duration(milliseconds: 300)), // 10
        one(CombinatorKind.throttle, const StageInput(10), d: const Duration(seconds: 1)), // 11
        one(CombinatorKind.delay, const StageInput(11), d: Duration.zero), // 12
        one(CombinatorKind.sample, const StageInput(12), d: const Duration(microseconds: 1500)), // 13
        one(CombinatorKind.buffer, const StageInput(13), d: const Duration(seconds: 2)), // 14
        one(CombinatorKind.timeout, const StageInput(13), d: const Duration(seconds: 5)), // 15
        one(CombinatorKind.catchError, const StageInput(15), f: n('recoverZero')), // 16
        one(CombinatorKind.rawEngine, const StageInput(16), f: n('passThrough')), // 17
        one(CombinatorKind.map, const StageInput(14), f: const FunctionRef.anonymous()), // 18
        one(CombinatorKind.map, const StageInput(8), f: n('describePair')), // 19
        one(CombinatorKind.map, t(_everyCount), f: n('label')), // 20
        TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[t(_everyTotal), t(_everyTaps)]), // 21
        TransformEdge.write(_everyOut.ref, const StageInput(17)),
        TransformEdge.write(_everySizes.ref, const StageInput(18)),
        TransformEdge.write(_everyLabel.ref, const StageInput(19)),
        TransformEdge.write(_everyNames.ref, const StageInput(20)),
        TransformEdge.reduceInto(_everyCount.ref, t(_everyTaps), n('reduceCount')),
        TransformEdge.reduceInto(_everyTotal.ref, const StageInput(21), n('reduceTotal')),
        TransformEdge.write(_everyLog.ref, t(_everyTaps)),
      ]);
    },
  ),
  (
    name: 'G8 recording one declaration twice projects equal definitions, inline closures included',
    body: (TopologyIrHarness h) async {
      final TopologyDefinition first = _everyCombinator.buildDefinition();
      final TopologyDefinition second = _everyCombinator.buildDefinition();
      await h.settle();
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    },
  ),
  // ------------------------------------------------------------ G9
  (
    name: 'G9 FunctionRef.of names a top-level function, a static method and a method tear-off, as the VM renders them',
    body: (TopologyIrHarness h) async {
      await h.settle();
      expect(FunctionRef.of(buildCheckoutUi).name, 'buildCheckoutUi');
      expect(FunctionRef.of(Reducers.reduceTotal).name, 'reduceTotal');
      expect(FunctionRef.of(const Labeler().label).name, 'label');
      expect(FunctionRef.of(to$Label).name, r'to$Label');
      expect(FunctionRef.of(buildCheckoutUi), FunctionRef.of(buildCheckoutUi));
    },
  ),
  (
    name: 'G9 FunctionRef.of is anonymous for a closure and a local function, and never calls the function',
    body: (TopologyIrHarness h) async {
      var calls = 0;
      int local(int v) => ++calls;
      int Function(int) closure() => (int v) => ++calls;
      await h.settle();
      expect(FunctionRef.of((int v) => ++calls), const FunctionRef.anonymous());
      expect(FunctionRef.of(local), const FunctionRef.anonymous());
      expect(FunctionRef.of(closure()), FunctionRef.of(closure()));
      expect(FunctionRef.of(closure()).name, isNull);
      expect(calls, 0);
      expect(() => FunctionRef.named(''), throwsArgumentError);
    },
  ),
  // ------------------------------------------------------------ G10
  (
    name: 'G10 scan and reduceInto bear state; debounce, delay, sample and buffer bear it only with a positive duration; nothing else does',
    body: (TopologyIrHarness h) async {
      final List<EdgeInput> one = <EdgeInput>[TopicInput(_ref('a'))];
      await h.settle();
      expect(TransformEdge.stage(CombinatorKind.scan, one, transformer: _f).isStateBearing, isTrue);
      expect(TransformEdge.reduceInto(_state('s'), one.single, _f).isStateBearing, isTrue);
      for (final CombinatorKind k in <CombinatorKind>[
        CombinatorKind.debounce,
        CombinatorKind.delay,
        CombinatorKind.sample,
        CombinatorKind.buffer,
      ]) {
        expect(TransformEdge.stage(k, one, duration: const Duration(microseconds: 1)).isStateBearing,
            isTrue, reason: k.name);
        expect(TransformEdge.stage(k, one, duration: Duration.zero).isStateBearing, isFalse,
            reason: k.name);
      }
      for (final CombinatorKind k in <CombinatorKind>[CombinatorKind.throttle, CombinatorKind.timeout]) {
        expect(TransformEdge.stage(k, one, duration: const Duration(seconds: 1)).isStateBearing, isFalse,
            reason: k.name);
      }
      for (final CombinatorKind k in <CombinatorKind>[
        CombinatorKind.map,
        CombinatorKind.filter,
        CombinatorKind.combine,
        CombinatorKind.switchMap,
        CombinatorKind.catchError,
        CombinatorKind.rawEngine,
      ]) {
        expect(TransformEdge.stage(k, one, transformer: _f).isStateBearing, isFalse, reason: k.name);
      }
      for (final CombinatorKind k in <CombinatorKind>[
        CombinatorKind.merge,
        CombinatorKind.pairwise,
        CombinatorKind.distinctUntilChanged,
      ]) {
        expect(TransformEdge.stage(k, one).isStateBearing, isFalse, reason: k.name);
      }
      expect(TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[...one, ...one], transformer: _f)
          .isStateBearing, isFalse);
      expect(TransformEdge.write(_ref('w'), one.single).isStateBearing, isFalse);
    },
  ),
  // ------------------------------------------------------------ G11
  (
    name: 'G11 a graph orders its topologies by id, keeps one of equal duplicates and lists every topic in canonical order',
    body: (TopologyIrHarness h) async {
      final TopologyDefinition b = _rw('b', Scope.page, <TopicRef>[_ref('t.2')], <TopicRef>[_state('t.1')]);
      final TopologyDefinition a = _rw('a', Scope.page, <TopicRef>[_ref('t.3')], <TopicRef>[_ref('t.2')]);
      final TopologyGraph g = TopologyGraph(
        topologies: <TopologyDefinition>[b, a, b],
        claims: <ShellClaim>[ShellClaim(source: const ServiceSource('s'), writes: <TopicRef>{_state('t.0')})],
      );
      await h.settle();
      expect(g.topologies, <TopologyDefinition>[a, b]);
      expect(g.topics, <TopicRef>[_state('t.0'), _state('t.1'), _ref('t.2'), _ref('t.3')]);
      expect(a.toGraph(), TopologyGraph(topologies: <TopologyDefinition>[a]));
      expect(TopologyGraph().topologies, isEmpty);
      expect(TopologyGraph().claims, isEmpty);
      expect(TopologyGraph().topics, isEmpty);
    },
  ),
  (
    name: 'G11 a graph rejects two different definitions with one id',
    body: (TopologyIrHarness h) async {
      final TopologyDefinition one = _rw('same', Scope.page, <TopicRef>[_ref('a')], <TopicRef>[_ref('b')]);
      final TopologyDefinition other = _rw('same', Scope.module, <TopicRef>[_ref('a')], <TopicRef>[_ref('b')]);
      await h.settle();
      expect(() => TopologyGraph(topologies: <TopologyDefinition>[one, other]), throwsArgumentError);
    },
  ),
  (
    name: 'G11 a graph orders its claims by source, scope and topics, and keeps equal claims as separate claimants',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = topologyIrSamples['claims_only']!();
      await h.settle();
      expect(<String>[for (final ShellClaim c in g.claims) '${c.source} ${c.scope.name}'], <String>[
        'executor:flutter-navigation application',
        'executor:wizard module',
        'page:settings/profile page',
        'service:auth application',
        'service:auth application',
      ]);
      expect(g.claims.first.writes.toList(), <TopicRef>[_currentRoute.ref, _navDepth.ref]);
    },
  ),
  // ------------------------------------------------------------ G12
  (
    name: 'G12 a shell claim takes a service, page or executor source, application scope by default, and one or more state topics',
    body: (TopologyIrHarness h) async {
      final Set<TopicRef> s = <TopicRef>{_state('a')};
      await h.settle();
      expect(ShellClaim(source: const ServiceSource('x'), writes: s).scope, Scope.application);
      expect(ShellClaim(source: const PageSource('x'), scope: Scope.page, writes: s).scope, Scope.page);
      expect(ShellClaim(source: const ExecutorSource('x'), writes: s).writes, s);
      expect(() => ShellClaim(source: const TopologySource('x'), writes: s), throwsArgumentError);
      expect(() => ShellClaim(source: const UnknownSource(), writes: s), throwsArgumentError);
      expect(() => ShellClaim(source: const ServiceSource('x'), writes: const <TopicRef>{}), throwsArgumentError);
      expect(() => ShellClaim(source: const ServiceSource('x'), writes: <TopicRef>{_ref('e')}), throwsArgumentError);
      expect(() => ShellClaim(source: const ServiceSource('x'), writes: <TopicRef>{_ref('r', TopicVariant.replay)}),
          throwsArgumentError);
    },
  ),
  // ------------------------------------------------------------ G13
  (
    name: 'G13 findTopologyCycles reports each strongly connected set of two or more topologies, with the topics between them',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = TopologyGraph(topologies: <TopologyDefinition>[
        _rw('c', Scope.page, <TopicRef>[_ref('y')], <TopicRef>[_ref('x')]),
        _rw('a', Scope.page, <TopicRef>[_ref('x')], <TopicRef>[_ref('w')]),
        _rw('b', Scope.page, <TopicRef>[_ref('w'), _ref('q')], <TopicRef>[_ref('y')]),
        _rw('d', Scope.page, <TopicRef>[_ref('y')], <TopicRef>[_ref('z')]),
        _rw('e', Scope.page, <TopicRef>[_state('s')], <TopicRef>[_ref('k')]),
        _rw('f', Scope.page, <TopicRef>[_ref('k')], <TopicRef>[_state('s')]),
        _rw('self', Scope.page, <TopicRef>[_ref('loop')], <TopicRef>[_ref('loop')]),
      ]);
      await h.settle();
      expect(findTopologyCycles(g), <TopologyCycle>[
        TopologyCycle(topologyIds: <String>['a', 'b', 'c'], topics: <TopicRef>[_ref('w'), _ref('x'), _ref('y')]),
        TopologyCycle(topologyIds: <String>['e', 'f'], topics: <TopicRef>[_ref('k'), _state('s')]),
      ]);
    },
  ),
  (
    name: 'G13 shell claims take no part in cycles, and a graph without feedback has none',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = TopologyGraph(
        topologies: <TopologyDefinition>[
          _rw('a', Scope.page, <TopicRef>[_state('s')], <TopicRef>[_ref('x')]),
          _rw('b', Scope.page, <TopicRef>[_ref('x')], <TopicRef>[_ref('y')]),
        ],
        claims: <ShellClaim>[ShellClaim(source: const ServiceSource('s'), writes: <TopicRef>{_state('s')})],
      );
      await h.settle();
      expect(findTopologyCycles(g), isEmpty);
      expect(findTopologyCycles(topologyIrSamples['checkout']!()), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G14
  (
    name: 'G14 findSelfReferences reports a self-written topic read through no state-bearing edge, with every edge on such a path',
    body: (TopologyIrHarness h) async {
      final List<TopologyDefinition> found = topologyIrSamples['findings']!().topologies;
      final TopologyDefinition echo = found.firstWhere((TopologyDefinition d) => d.topologyId == 'echo');
      final TopologyDefinition quiet = found.firstWhere((TopologyDefinition d) => d.topologyId == 'quiet');
      final TopologyDefinition direct = _def('direct', Scope.page, <TransformEdge>[
        TransformEdge.write(_state('d'), TopicInput(_state('d'))),
      ]);
      await h.settle();
      expect(findSelfReferences(echo),
          <SelfReference>[SelfReference(topologyId: 'echo', topic: _echo.ref, edges: <int>[0, 1])]);
      expect(findSelfReferences(quiet),
          <SelfReference>[SelfReference(topologyId: 'quiet', topic: _quiet.ref, edges: <int>[0, 2, 3])]);
      expect(findSelfReferences(direct),
          <SelfReference>[SelfReference(topologyId: 'direct', topic: _state('d'), edges: <int>[0])]);
    },
  ),
  (
    name: 'G14 a self-read mediated by scan, reduceInto or a positive time stage, or never reaching its write, is not reported',
    body: (TopologyIrHarness h) async {
      final TopologyDefinition mediated = _def('mediated', Scope.page, <TransformEdge>[
        TransformEdge.stage(CombinatorKind.scan, <EdgeInput>[TopicInput(_state('a'))], transformer: _f),
        TransformEdge.stage(CombinatorKind.sample, <EdgeInput>[TopicInput(_state('b'))],
            duration: const Duration(microseconds: 1)),
        _map(const StageInput(1)),
        TransformEdge.write(_state('a'), const StageInput(0)),
        TransformEdge.write(_state('b'), const StageInput(2)),
        TransformEdge.reduceInto(_state('c'), TopicInput(_state('c')), _f),
        TransformEdge.write(_ref('e'), TopicInput(_ref('e2'))),
        TransformEdge.write(_ref('e2'), TopicInput(_ref('e3'))),
      ]);
      await h.settle();
      expect(findSelfReferences(mediated), isEmpty);
      expect(findSelfReferences(_everyCombinator.buildDefinition()), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G15
  (
    name: 'G15 findWriterConflicts reports each state topic with two or more writers, topologies and claims alike',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = TopologyGraph(
        topologies: <TopologyDefinition>[
          _rw('t1', Scope.page, <TopicRef>[_ref('in')], <TopicRef>[_state('s'), _ref('e')]),
          _rw('t2', Scope.page, <TopicRef>[_ref('in')], <TopicRef>[_state('s'), _ref('e')]),
          _rw('t3', Scope.page, <TopicRef>[_ref('in')], <TopicRef>[_state('only')]),
        ],
        claims: <ShellClaim>[
          ShellClaim(source: const ServiceSource('svc'), writes: <TopicRef>{_state('s'), _state('c')}),
          ShellClaim(source: const ServiceSource('svc'), writes: <TopicRef>{_state('c')}),
        ],
      );
      await h.settle();
      expect(findWriterConflicts(g), <WriterConflict>[
        WriterConflict(topic: _state('c'), writers: const <MessageSource>[ServiceSource('svc'), ServiceSource('svc')]),
        WriterConflict(
            topic: _state('s'),
            writers: const <MessageSource>[ServiceSource('svc'), TopologySource('t1'), TopologySource('t2')]),
      ]);
      expect(findWriterConflicts(topologyIrSamples['checkout']!()), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G16
  (
    name: 'G16 findScopeViolations reports each owner of a state topic that a longer-lived topology reads',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = TopologyGraph(
        topologies: <TopologyDefinition>[
          _rw('owner', Scope.module, <TopicRef>[_ref('in')], <TopicRef>[_state('m')]),
          _rw('app-reader', Scope.application, <TopicRef>[_state('m'), _state('p'), _ref('ev')], <TopicRef>[_ref('o1')]),
          _rw('mod-reader', Scope.module, <TopicRef>[_state('m'), _state('p')], <TopicRef>[_ref('o2')]),
          _rw('page-reader', Scope.page, <TopicRef>[_state('m'), _state('p')], <TopicRef>[_ref('o3')]),
          _rw('ev-owner', Scope.page, <TopicRef>[_ref('in')], <TopicRef>[_ref('ev')]),
        ],
        claims: <ShellClaim>[
          ShellClaim(source: const PageSource('form'), scope: Scope.page, writes: <TopicRef>{_state('p')}),
          ShellClaim(source: const PageSource('form'), scope: Scope.page, writes: <TopicRef>{_state('p')}),
        ],
      );
      await h.settle();
      expect(findScopeViolations(g), <ScopeViolation>[
        ScopeViolation(
            topic: _state('m'),
            owner: const TopologySource('owner'),
            ownerScope: Scope.module,
            readerId: 'app-reader',
            readerScope: Scope.application),
        ScopeViolation(
            topic: _state('p'),
            owner: const PageSource('form'),
            ownerScope: Scope.page,
            readerId: 'app-reader',
            readerScope: Scope.application),
        ScopeViolation(
            topic: _state('p'),
            owner: const PageSource('form'),
            ownerScope: Scope.page,
            readerId: 'mod-reader',
            readerScope: Scope.module),
      ]);
      expect(findScopeViolations(topologyIrSamples['checkout']!()), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G17
  (
    name: 'G17 analyzeTopologyGraph lists cycles, then self-references by topology, then writer conflicts, then scope violations',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = topologyIrSamples['findings']!();
      await h.settle();
      expect(analyzeTopologyGraph(g), <TopologyFinding>[
        TopologyCycle(topologyIds: <String>['ping', 'pong'], topics: <TopicRef>[_loopA.ref, _loopB.ref]),
        SelfReference(topologyId: 'echo', topic: _echo.ref, edges: <int>[0, 1]),
        SelfReference(topologyId: 'quiet', topic: _quiet.ref, edges: <int>[0, 2, 3]),
        WriterConflict(
            topic: _settled.ref,
            writers: const <MessageSource>[ServiceSource('settings-sync'), TopologySource('settings-owner')]),
        ScopeViolation(
            topic: _bannerText.ref,
            owner: const TopologySource('banner'),
            ownerScope: Scope.page,
            readerId: 'header',
            readerScope: Scope.application),
        ScopeViolation(
            topic: _formDraft.ref,
            owner: const PageSource('checkout/cart'),
            ownerScope: Scope.page,
            readerId: 'summary',
            readerScope: Scope.module),
      ]);
    },
  ),
  (
    name: 'G17 a graph with no finding stays without one when topologies or claims are removed',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = topologyIrSamples['checkout']!();
      await h.settle();
      expect(analyzeTopologyGraph(g), isEmpty);
      for (var i = 0; i < g.topologies.length; i++) {
        final TopologyGraph less = TopologyGraph(
            topologies: <TopologyDefinition>[...g.topologies]..removeAt(i), claims: g.claims);
        expect(analyzeTopologyGraph(less), isEmpty);
      }
      for (var i = 0; i < g.claims.length; i++) {
        final TopologyGraph less = TopologyGraph(
            topologies: g.topologies, claims: <ShellClaim>[...g.claims]..removeAt(i));
        expect(analyzeTopologyGraph(less), isEmpty);
      }
    },
  ),
  // ------------------------------------------------------------ G18
  (
    name: 'G18 findTopicNameCollisions reports each name with two or more distinct declarations, whatever their types',
    body: (TopologyIrHarness h) async {
      final TopicDeclaration a1 = TopicDeclaration(topic: _state('cart.items', 'Cart'), site: 'lib/a.dart:3');
      final TopicDeclaration a2 = TopicDeclaration(topic: _ref('cart.items', TopicVariant.event, 'Cart'), site: 'lib/b.dart:9');
      final TopicDeclaration a3 = TopicDeclaration(topic: _state('cart.items', 'Cart'), site: 'lib/c.dart:1');
      final TopicDeclaration b1 = TopicDeclaration(topic: _state('auth.state', 'Auth'), site: 'lib/a.dart:4');
      final TopicDeclaration c1 = TopicDeclaration(topic: _state('a.b', 'X'), site: 'lib/z.dart:1');
      await h.settle();
      expect(findTopicNameCollisions(<TopicDeclaration>[a3, b1, a2, a1, b1, c1, c1]), <TopicNameCollision>[
        TopicNameCollision(name: 'cart.items', declarations: <TopicDeclaration>[a1, a2, a3]),
      ]);
      expect(findTopicNameCollisions(<TopicDeclaration>[b1, b1, c1]), isEmpty);
      expect(findTopicNameCollisions(const <TopicDeclaration>[]), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G19
  (
    name: 'G19 the encoding of every sample graph matches the schema and equals its valid/ file',
    body: (TopologyIrHarness h) async {
      await h.settle();
      expect(_cases('valid'), (topologyIrSamples.keys.toList()..sort()));
      for (final MapEntry<String, TopologyGraph Function()> s in topologyIrSamples.entries) {
        final Map<String, Object?> encoded = encodeTopologyGraph(s.value());
        expectMatchesSchema(encoded, _schema);
        expect(encoded, _json('valid', s.key), reason: s.key);
      }
    },
  ),
  (
    name: 'G19 a definition encodes to the object its graph document lists',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = topologyIrSamples['checkout']!();
      final Map<String, Object?> doc = encodeTopologyGraph(g);
      await h.settle();
      expect(doc.keys, <String>['format', 'topologies', 'claims']);
      expect(doc['format'], 'topology-ir@v1');
      expect(doc['topologies'],
          <Object?>[for (final TopologyDefinition d in g.topologies) encodeTopologyDefinition(d)]);
    },
  ),
  // ------------------------------------------------------------ G20
  (
    name: 'G20 every valid/ file decodes and re-encodes to an equal JSON value',
    body: (TopologyIrHarness h) async {
      await h.settle();
      final List<String> names = _cases('valid');
      expect(names, isNotEmpty);
      for (final String name in names) {
        final Object? doc = _json('valid', name);
        expectMatchesSchema(doc, _schema);
        expect(encodeTopologyGraph(decodeTopologyGraph(doc)), doc, reason: name);
      }
    },
  ),
  (
    name: 'G20 decoding the encoding of a graph gives the graph back',
    body: (TopologyIrHarness h) async {
      await h.settle();
      for (final MapEntry<String, TopologyGraph Function()> s in topologyIrSamples.entries) {
        final TopologyGraph g = s.value();
        expect(decodeTopologyGraph(jsonDecode(jsonEncode(encodeTopologyGraph(g)))), g, reason: s.key);
      }
    },
  ),
  (
    name: 'G20 the decoder accepts topologies, claims, reads, writes and claimed topics in any order',
    body: (TopologyIrHarness h) async {
      final Object? doc = _json('valid', 'checkout');
      final Object? shuffled = _edited(doc, (Map<String, Object?> d) {
        final List<Object?> topologies = d['topologies']! as List<Object?>;
        final List<Object?> claims = d['claims']! as List<Object?>;
        d['topologies'] = topologies.reversed.toList();
        d['claims'] = claims.reversed.toList();
        for (final Object? t in topologies) {
          final Map<String, Object?> m = t! as Map<String, Object?>;
          m['reads'] = (m['reads']! as List<Object?>).reversed.toList();
          m['writes'] = (m['writes']! as List<Object?>).reversed.toList();
        }
        for (final Object? c in claims) {
          final Map<String, Object?> m = c! as Map<String, Object?>;
          m['writes'] = (m['writes']! as List<Object?>).reversed.toList();
        }
      });
      await h.settle();
      expectMatchesSchema(shuffled, _schema);
      expect(decodeTopologyGraph(shuffled), decodeTopologyGraph(doc));
      expect(encodeTopologyGraph(decodeTopologyGraph(shuffled)), doc);
    },
  ),
  // ------------------------------------------------------------ G21
  (
    name: 'G21 every invalid/ file fails the schema and the decoder rejects it with a FormatException',
    body: (TopologyIrHarness h) async {
      await h.settle();
      final List<String> names = _cases('invalid');
      expect(names, isNotEmpty);
      for (final String name in names) {
        final Object? doc = _json('invalid', name);
        expect(() => expectMatchesSchema(doc, _schema), throwsA(isA<Exception>()), reason: name);
        expect(() => decodeTopologyGraph(doc), _throwsFormat, reason: name);
      }
    },
  ),
  (
    name: 'G21 the decoder rejects a schema-valid document that breaks a rule the schema cannot state',
    body: (TopologyIrHarness h) async {
      final Object? doc = _json('valid', 'checkout');
      // checkout-flow is topologies[1]: a combine (edge 0), a map (edge 1),
      // then a write of edge 0 and a write of edge 1.
      final Map<String, Object? Function()> broken = <String, Object? Function()>{
        'a forward edge reference': () => _edited(doc, (Map<String, Object?> d) {
              (_transforms(d, 1)[2]! as Map<String, Object?>)['inputs'] = <Object?>[
                <String, Object?>{'edge': 3},
              ];
            }),
        'a reference to a sink edge': () => _edited(doc, (Map<String, Object?> d) {
              (_transforms(d, 1)[3]! as Map<String, Object?>)['inputs'] = <Object?>[
                <String, Object?>{'edge': 2},
              ];
            }),
        'a stage after a sink': () => _edited(doc, (Map<String, Object?> d) {
              final List<Object?> t = _transforms(d, 1);
              final Object? map = t[1];
              t[1] = t[2];
              t[2] = map;
              (t[3]! as Map<String, Object?>)['inputs'] = <Object?>[
                <String, Object?>{'edge': 2},
              ];
            }),
        'an unconsumed stage': () => _edited(doc, (Map<String, Object?> d) {
              (_transforms(d, 1)[3]! as Map<String, Object?>)['inputs'] = <Object?>[
                <String, Object?>{'edge': 0},
              ];
            }),
        'reads that miss a topic': () => _edited(doc, (Map<String, Object?> d) {
              (_topology(d, 1)['reads']! as List<Object?>).removeLast();
            }),
        'writes that name an extra topic': () => _edited(doc, (Map<String, Object?> d) {
              (_topology(d, 1)['writes']! as List<Object?>)
                  .add(<String, Object?>{'name': 'extra', 'variant': 'event', 'typeName': 'int'});
            }),
        'two topologies with one id': () => _edited(doc, (Map<String, Object?> d) {
              _topology(d, 1)['topologyId'] = _topology(d, 0)['topologyId'];
            }),
        'two sinks on one state topic': () => _edited(doc, (Map<String, Object?> d) {
              final List<Object?> t = _transforms(d, 1);
              (t[3]! as Map<String, Object?>)['output'] = (t[2]! as Map<String, Object?>)['output'];
              final List<Object?> writes = _topology(d, 1)['writes']! as List<Object?>;
              writes.removeWhere((Object? w) => (w! as Map<String, Object?>)['name'] == 'order.request');
            }),
      };
      await h.settle();
      for (final MapEntry<String, Object? Function()> b in broken.entries) {
        final Object? bad = b.value();
        expectMatchesSchema(bad, _schema);
        expect(() => decodeTopologyGraph(bad), _throwsFormat, reason: b.key);
      }
    },
  ),
  (
    name: 'G21 the decoder rejects any other value with a FormatException and no other error',
    body: (TopologyIrHarness h) async {
      final Object? doc = _json('valid', 'every_combinator');
      final List<Object?> bad = <Object?>[
        null,
        42,
        'topology-ir@v1',
        <Object?>[],
        <String, Object?>{},
        _edited(doc, (Map<String, Object?> d) => d['topologies'] = <String, Object?>{}),
        _edited(doc, (Map<String, Object?> d) => _topology(d, 0)['transforms'] = <Object?>[42]),
        _edited(doc, (Map<String, Object?> d) => _topology(d, 0)['scope'] = 3),
        _edited(doc, (Map<String, Object?> d) =>
            (_transforms(d, 0)[0]! as Map<String, Object?>)['inputs'] = <Object?>[<String, Object?>{'edge': 'x'}]),
        _edited(doc, (Map<String, Object?> d) =>
            (_transforms(d, 0)[10]! as Map<String, Object?>)['durationMicros'] = 1.5),
        _edited(doc, (Map<String, Object?> d) => d['claims'] = <Object?>[<String, Object?>{'source': 1}]),
      ];
      await h.settle();
      for (final Object? b in bad) {
        expect(() => decodeTopologyGraph(b), _throwsFormat, reason: '$b');
      }
      expect(() => decodeTopologyDefinition(<String, Object?>{'topologyId': 'x'}), _throwsFormat);
    },
  ),
  // ------------------------------------------------------------ G22
  (
    name: 'G22 the Mermaid and Graphviz renderings of every sample equal its render/ files',
    body: (TopologyIrHarness h) async {
      await h.settle();
      for (final MapEntry<String, TopologyGraph Function()> s in topologyIrSamples.entries) {
        final TopologyGraph g = s.value();
        expect(g.render(const MermaidRenderer()), _read('render/${s.key}.mmd'), reason: s.key);
        expect(g.render(const GraphvizRenderer()), _read('render/${s.key}.dot'), reason: s.key);
      }
    },
  ),
  (
    name: 'G22 the JSON rendering of every sample is its valid/ file, byte for byte',
    body: (TopologyIrHarness h) async {
      await h.settle();
      for (final MapEntry<String, TopologyGraph Function()> s in topologyIrSamples.entries) {
        expect(s.value().render(const JsonRenderer()), _read('valid/${s.key}.json'), reason: s.key);
      }
    },
  ),
  (
    name: 'G22 render passes the graph to the renderer, and renderers are pure',
    body: (TopologyIrHarness h) async {
      final TopologyGraph g = topologyIrSamples['findings']!();
      final _Counting counting = _Counting();
      var scheduled = 0;
      final List<String> texts = runZoned(
        () => <String>[
          g.render(counting),
          g.render(const MermaidRenderer()),
          g.render(const GraphvizRenderer()),
          g.render(const JsonRenderer()),
          jsonEncode(analyzeTopologyGraph(g).map((TopologyFinding f) => '$f').toList()),
          '${decodeTopologyGraph(encodeTopologyGraph(g))}',
        ],
        zoneSpecification: ZoneSpecification(
          createTimer: (Zone self, ZoneDelegate parent, Zone zone, Duration duration, void Function() f) {
            scheduled++;
            return parent.createTimer(zone, duration, f);
          },
          createPeriodicTimer: (Zone self, ZoneDelegate parent, Zone zone, Duration period,
              void Function(Timer timer) f) {
            scheduled++;
            return parent.createPeriodicTimer(zone, period, f);
          },
          scheduleMicrotask: (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
            scheduled++;
            parent.scheduleMicrotask(zone, f);
          },
        ),
      );
      await h.settle();
      expect(texts.first, 'counted');
      expect(counting.seen, <TopologyGraph>[g]);
      expect(scheduled, 0);
      expect(g.render(const MermaidRenderer()), texts[1]);
    },
  ),
];

/// A renderer an application writes (Spec Appendix A.4 "other graph formats").
final class _Counting implements GraphRenderer {
  final List<TopologyGraph> seen = <TopologyGraph>[];

  @override
  String render(TopologyGraph graph) {
    seen.add(graph);
    return 'counted';
  }
}
