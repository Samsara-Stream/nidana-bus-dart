// Surface fixture for topology-dsl@v1: the app-facing declarations of the
// main library, used the way topology modules use them. Every builder method
// and every handle method appears with the types the Interface states.
// Passes when `fvm dart analyze --fatal-infos` reports nothing on it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// ------------------------------------------------------------ data contracts

final class CartItems {
  const CartItems(this.count);
  final int count;
}

sealed class AuthState {
  const AuthState();
}

final class Initializing extends AuthState {
  const Initializing();
}

final class Authenticated extends AuthState {
  const Authenticated(this.user);
  final String user;
}

final class CheckoutUi {
  const CheckoutUi(this.canCheckout);
  final bool canCheckout;
}

final class SubmitIntent {
  const SubmitIntent();
}

final class OrderRequest {
  const OrderRequest(this.items);
  final int items;
}

sealed class CheckoutEvent {
  const CheckoutEvent();
}

final class ItemAdded extends CheckoutEvent {
  const ItemAdded();
}

final class LoggedOut extends CheckoutEvent {
  const LoggedOut();
}

final class SearchResult {
  const SearchResult(this.hits);
  final int hits;
}

// ------------------------------------------------------------ registries

abstract final class CheckoutTopics {
  static const StateTopic<CartItems> cartItems =
      StateTopic<CartItems>(name: 'checkout.cart-items', initial: CartItems(0));
  static const StateTopic<CheckoutUi> ui =
      StateTopic<CheckoutUi>(name: 'checkout.ui-state', initial: CheckoutUi(false));
  static const EventTopic<SubmitIntent> submit =
      EventTopic<SubmitIntent>(name: 'checkout.submit-order');
  static const EventTopic<OrderRequest> orders =
      EventTopic<OrderRequest>(name: 'order.request');
  static const EventTopic<CheckoutEvent> events =
      EventTopic<CheckoutEvent>(name: 'checkout.events');
  static const ReplayTopic<String> log =
      ReplayTopic<String>(name: 'checkout.log', bufferSize: 10);
  static const StateTopic<String> query =
      StateTopic<String>(name: 'search.query', initial: '');
  static const StateTopic<int> hits =
      StateTopic<int>(name: 'search.hits', initial: 0);
  static const StateTopic<bool> beta =
      StateTopic<bool>(name: 'search.beta', initial: false);
}

abstract final class AuthTopics {
  static const StateTopic<AuthState> state =
      StateTopic<AuthState>(name: 'auth.state', initial: Initializing());
  static const EventTopic<CheckoutEvent> logout =
      EventTopic<CheckoutEvent>(name: 'auth.logout');
}

// ------------------------------------------------------------ transformers

CheckoutUi buildCheckoutUi(CartItems cart, AuthState auth) =>
    CheckoutUi(auth is Authenticated && cart.count > 0);

OrderRequest toOrderRequest(SubmitIntent intent, CartItems cart) =>
    OrderRequest(cart.count);

CartItems reduceCart(CartItems cart, CheckoutEvent event) => switch (event) {
      ItemAdded() => CartItems(cart.count + 1),
      LoggedOut() => const CartItems(0),
    };

Stream<SearchResult> searchApi(String query) =>
    Stream<SearchResult>.value(SearchResult(query.length));

Duration? retryTwice(Object error, int attempt) =>
    attempt <= 2 ? Duration(milliseconds: 100 * attempt) : null;

/// A raw-engine operator: it applies the lineage rules itself (Spec §3.5).
Stream<PipelineValue<int>> lengths(
  Stream<PipelineValue<String>> values,
  String Function() freshCorrelationId,
) =>
    values.map((PipelineValue<String> v) =>
        (payload: v.payload.length, lineage: v.lineage));

// ------------------------------------------------------------ class form

/// A module-local typed identifier (Spec §4.6), never exported.
const TopologyRef _checkoutFlow = TopologyRef('checkout-flow');

final class CheckoutTopology extends Topology {
  const CheckoutTopology();

  @override
  String get topologyId => _checkoutFlow.id;

  @override
  Scope get scope => Scope.module;

  @override
  void declare(TopologyBuilder b) {
    final TopicStream<CartItems> cart = b.read(CheckoutTopics.cartItems);
    final TopicStream<AuthState> auth =
        b.read(AuthTopics.state, dedup: Dedup.none);
    final TopicStream<CheckoutUi> ui = b.combine2(cart, auth, buildCheckoutUi);
    b.write(CheckoutTopics.ui, ui);

    final TopicStream<OrderRequest> orders = b
        .read(CheckoutTopics.submit)
        .withLatestFrom(cart, toOrderRequest);
    b.write(CheckoutTopics.orders, orders);
  }
}

/// A reducer topology (Spec §2.5, §6.4): it owns the state it folds into.
final Topology cartReducer = topology(
  'checkout-cart-reducer',
  Scope.module,
  (TopologyBuilder b) {
    final TopicStream<CheckoutEvent> events =
        b.merge(<TopicStream<CheckoutEvent>>[
      b.read(CheckoutTopics.events),
      b.read(AuthTopics.logout),
    ]);
    b.reduceInto(CheckoutTopics.cartItems, events, reduceCart);
  },
);

// ------------------------------------------------------------ builder form

/// The remaining builder methods and every handle method.
final Topology searchTopology = topology(
  'search',
  Scope.page,
  (TopologyBuilder b) {
    final TopicStream<String> query = b.read(CheckoutTopics.query);
    final TopicStream<bool> beta = b.read(CheckoutTopics.beta);
    final TopicStream<int> lengthOf = query.map((String q) => q.length);
    final TopicStream<int> nonEmpty = lengthOf.filter((int n) => n > 0);

    final TopicStream<SearchResult> live = query
        .debounce(const Duration(milliseconds: 300))
        .switchMap(searchApi, retry: retryTwice);
    final TopicStream<SearchResult> stable = query.switchMap(searchApi);
    // Selecting between two pipelines on a configuration topic (Spec §6.1).
    final TopicStream<SearchResult> chosen = b.combine3(
        beta,
        live,
        stable,
        (bool on, SearchResult fresh, SearchResult old) => on ? fresh : old);
    final TopicStream<SearchResult> guarded = chosen
        .timeout(const Duration(seconds: 5))
        .catchError((Object error, StackTrace stackTrace) =>
            const SearchResult(0));
    final TopicStream<int> hits = guarded.map((SearchResult r) => r.hits);

    final TopicStream<int> c3 = b.combine3(
        nonEmpty, hits, lengthOf, (int a, int h, int c) => a + h + c);
    final TopicStream<int> c4 = b.combine4(nonEmpty, hits, lengthOf, c3,
        (int a, int h, int c, int d) => a + h + c + d);
    final TopicStream<int> all = b.combineAll(
        <TopicStream<int>>[c3, c4], (List<int> values) => values.length);

    final TopicStream<int> w2 = all.withLatestFrom2(
        hits, lengthOf, (int a, int h, int c) => a + h + c);
    final TopicStream<int> w3 = w2.withLatestFrom3(
        hits, lengthOf, c3, (int a, int h, int c, int d) => a + h + c + d);

    final TopicStream<int> total = w3
        .scan(0, (int acc, int n) => acc + n)
        .distinctUntilChanged()
        .throttle(const Duration(milliseconds: 100))
        .delay(Duration.zero)
        .sample(const Duration(seconds: 1));
    final TopicStream<({int previous, int current})> pairs = total.pairwise();
    final TopicStream<int> deltas = pairs.map(
        (({int previous, int current}) p) => p.current - p.previous);
    final TopicStream<List<int>> batches =
        deltas.buffer(const Duration(seconds: 2));
    final TopicStream<int> sizes = batches.map((List<int> xs) => xs.length);
    final TopicStream<int> raw = query.rawEngine(lengths);

    b.write(CheckoutTopics.hits, b.merge(<TopicStream<int>>[sizes, raw]));
    b.write(CheckoutTopics.log, query);
  },
);

// ------------------------------------------------------------ the IR

/// What a catalog does with a topology (Spec §6.5, §4.6).
Set<TopicRef> writesOf(Topology t) {
  final TopologyDefinition definition = t.buildDefinition();
  final String id = definition.topologyId;
  final Scope scope = definition.scope;
  final Set<TopicRef> reads = definition.reads;
  return id.isEmpty || scope == Scope.application || reads.isEmpty
      ? const <TopicRef>{}
      : definition.writes;
}

final Set<TopicRef> checkoutWrites = writesOf(const CheckoutTopology());

/// The typedefs, written out.
const RetryPolicy noRetry = _never;
Duration? _never(Object error, int attempt) => null;
const RawOperator<String, int> lengthOperator = lengths;
final PipelineValue<int> example = (payload: 1, lineage: const Lineage.root());
final bool sameRef = const TopologyRef('a') == const TopologyRef('a');
