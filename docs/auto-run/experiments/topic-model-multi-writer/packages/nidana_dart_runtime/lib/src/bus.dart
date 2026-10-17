/// Stand-in for the runtime of `nidana_dart_runtime` (experiment only).
///
/// Throwaway experiment code: it implements the Interface of
/// hsdd/contract/bus-api.md as directly as possible, on RxDart 0.28 sync
/// subjects, so that the contract's surface, reject and behavior fixtures
/// can be replayed before the real package exists. The parts hold the
/// virtual scheduler and TestBus (the bus-testing@v1 surface the bindings
/// assume), the live interpreter, and the diagnostic and error types. It is
/// not the runtime's design and nothing should depend on it.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:clock/clock.dart' as c;
import 'package:meta/meta.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:rxdart/rxdart.dart';

part 'diagnostics.dart';
part 'interpreter.dart';
part 'testing.dart';

// ------------------------------------------------------------ providers

/// The source of time and scheduling of a bus (Spec §3.6; ADR-003 item 1).
sealed class SchedulerProvider {
  const SchedulerProvider();
}

/// The zone current when a bus is constructed, unforked, and
/// package:clock's clock as read then.
final class ProductionSchedulerProvider extends SchedulerProvider {
  const ProductionSchedulerProvider();
}

// ------------------------------------------------------------ config

typedef DiagnosticSink = void Function(BusDiagnostic diagnostic);

@immutable
final class BusConfig {
  const BusConfig({
    this.scheduler,
    this.devMode,
    this.diagnostics,
    this.observeContext,
    this.maxTopics = 1000,
    this.maxActiveTopologies = 200,
    this.maxObservers = 20,
    this.maxReentrancyDepth = 10,
    this.moduleScopeGracePeriod = const Duration(milliseconds: 100),
    this.startupWindow = const Duration(seconds: 5),
  });

  final SchedulerProvider? scheduler;
  final bool? devMode;
  final DiagnosticSink? diagnostics;
  final ObserveContext? observeContext;
  final int maxTopics;
  final int maxActiveTopologies;
  final int maxObservers;
  final int maxReentrancyDepth;
  final Duration moduleScopeGracePeriod;
  final Duration startupWindow;
}

enum BusLifecycle { bootstrapping, running, shutDown }

// ------------------------------------------------------------ cells

typedef _D<T> = ({T payload, MessageEnvelope<T>? envelope});

final class _Cell<T> {
  _Cell(this.topic)
      : subject = switch (topic) {
          StateTopic<T> t => BehaviorSubject<_D<T>>.seeded(
              (payload: t.createInitial(), envelope: null),
              sync: true),
          EventTopic<T>() => PublishSubject<_D<T>>(sync: true),
          ReplayTopic<T> t =>
            ReplaySubject<_D<T>>(maxSize: t.bufferSize, sync: true),
        } {
    final s = subject;
    if (s is BehaviorSubject<_D<T>>) _last = s.value.payload;
  }

  final Topic<T> topic;
  final Subject<_D<T>> subject;
  final Set<StreamController<T>> observers = <StreamController<T>>{};
  T? _last;
  final List<T> _buffer = <T>[];

  T get current => _last as T;

  List<T> get buffered => List<T>.unmodifiable(_buffer);

  void add(MessageEnvelope<T> e) {
    final t = topic;
    if (t is StateTopic<T>) _last = e.payload;
    if (t is ReplayTopic<T>) {
      _buffer.add(e.payload);
      if (_buffer.length > t.bufferSize) _buffer.removeAt(0);
    }
    subject.add((payload: e.payload, envelope: e));
  }

  /// Ends every observed subscription, synchronously: [error] first when
  /// given, then done.
  void end([Object? error]) {
    for (final c in List<StreamController<T>>.of(observers)) {
      if (error != null) c.addError(error);
      c.close();
    }
    observers.clear();
    subject.close();
  }

  /// A subscription with the read's effective dedup policy.
  Stream<_D<T>> stream(Dedup dedup) {
    final s = subject.stream;
    if (dedup == Dedup.none || topic is! StateTopic<T>) return s;
    return s.distinct((a, b) => a.payload == b.payload);
  }
}

bool _sameDeclaration(Topic<Object?> a, Topic<Object?> b) {
  if (a.variant != b.variant || a.valueType != b.valueType) return false;
  if (a.sensitive != b.sensitive || a.tracing != b.tracing) return false;
  if (a is StateTopic<Object?> && b is StateTopic<Object?>) {
    return a.dedup == b.dedup;
  }
  if (a is ReplayTopic<Object?> && b is ReplayTopic<Object?>) {
    return a.bufferSize == b.bufferSize;
  }
  return true;
}

// ------------------------------------------------------------ pending

final class _Pending {
  _Pending(this.owner, this.chain, this.deliver);
  final Object? owner;
  List<TopicRef> chain;
  final void Function() deliver;
}

// ------------------------------------------------------------ bus

bool _assertionsEnabled() {
  var on = false;
  assert(on = true);
  return on;
}

final class Bus {
  Bus([BusConfig config = const BusConfig()]) : this._(config, config.scheduler);

  Bus._(this.config, SchedulerProvider? provider)
      : devMode = config.devMode ?? _assertionsEnabled() {
    if (config.maxTopics < 1 ||
        config.maxActiveTopologies < 1 ||
        config.maxObservers < 1 ||
        config.maxReentrancyDepth < 1) {
      throw ArgumentError('a limit is below 1');
    }
    if (config.moduleScopeGracePeriod.isNegative ||
        config.startupWindow.isNegative) {
      throw ArgumentError('a duration is negative');
    }
    switch (provider) {
      case null || ProductionSchedulerProvider():
        _zone = Zone.current;
        clock = c.clock;
      case VirtualSchedulerProvider(:final scheduler):
        _zone = scheduler.zone;
        clock = scheduler.clock;
    }
    _context = config.observeContext ?? const _DefaultContext();
  }

  final BusConfig config;
  final bool devMode;
  late final c.Clock clock;
  late final Zone _zone;
  late final ObserveContext _context;
  BusLifecycle _lifecycle = BusLifecycle.bootstrapping;

  final Map<String, _Cell<Object?>> _cells = <String, _Cell<Object?>>{};
  final List<BusObserver> _observers = <BusObserver>[];
  final LinkedHashMap<String, _Activation> _active =
      LinkedHashMap<String, _Activation>();
  final List<Publisher> _publishers = <Publisher>[];
  final Map<String, ModuleScope> _modules = <String, ModuleScope>{};
  final Queue<_Pending> _deferred = Queue<_Pending>();
  bool _drainScheduled = false;
  final List<_Pending> _startupQueue = <_Pending>[];
  Timer? _windowTimer;
  int _delivering = 0;
  List<TopicRef> _chain = const <TopicRef>[];
  final List<void Function()> _shutdownCallbacks = <void Function()>[];
  EnvelopeRecorder? _recorder;

  final String _prefix =
      Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  int _ids = 0;
  int _correlations = 0;

  BusLifecycle get lifecycle => _lifecycle;

  String _freshId() => '$_prefix-e${++_ids}';
  String _freshCorrelationId() => '$_prefix-c${++_correlations}';

  void _checkOpen() {
    if (_lifecycle == BusLifecycle.shutDown) {
      throw StateError('the bus is shut down');
    }
  }

  // ---------------------------------------------------------- registry

  _Cell<T> _cell<T>(Topic<T> topic, {bool counted = true}) {
    final existing = _cells[topic.name];
    if (existing != null) {
      if (!_sameDeclaration(existing.topic, topic)) {
        throw TopicCollision(registered: existing.topic, requested: topic);
      }
      return existing as _Cell<T>;
    }
    if (counted && _cells.length >= config.maxTopics) {
      _report(TopicLimitExceeded(topic: topic.ref, maxTopics: config.maxTopics));
    }
    final c = _Cell<T>(topic);
    _cells[topic.name] = c;
    return c;
  }

  void _checkName(Topic<Object?> topic) {
    final existing = _cells[topic.name];
    if (existing != null && !_sameDeclaration(existing.topic, topic)) {
      throw TopicCollision(registered: existing.topic, requested: topic);
    }
  }

  T getCurrentValue<T>(StateTopic<T> topic) {
    if (_lifecycle == BusLifecycle.shutDown) {
      final c = _cells[topic.name];
      return c == null ? topic.createInitial() : (c as _Cell<T>).current;
    }
    return _cell(topic).current;
  }

  List<T> getBufferedValues<T>(ReplayTopic<T> topic) {
    if (_lifecycle == BusLifecycle.shutDown) {
      final c = _cells[topic.name];
      return c == null ? List<T>.unmodifiable(<T>[]) : (c as _Cell<T>).buffered;
    }
    return _cell(topic).buffered;
  }

  Stream<T> observe<T>(Topic<T> topic) {
    _checkOpen();
    _cell(topic);
    return _ObserveStream<T>(this, topic);
  }

  bool removeTopic(Topic<Object?> topic, {bool force = false}) {
    _checkOpen();
    if (_delivering > 0) throw StateError('removeTopic during a delivery');
    _checkName(topic);
    final c = _cells[topic.name];
    if (c == null) return true;
    if (c.subject.hasListener && !force) return false;
    _cells.remove(topic.name);
    _zone.run(() {
      final removed = TopicRemoved(topic.ref);
      c.subject.addError(removed);
      c.end(removed);
    });
    return true;
  }

  // ---------------------------------------------------------- publishing

  void publish<T>(MultiWriterTopic<T> topic, T value) {
    _checkOpen();
    _publish(topic, value,
        lineage: const Lineage.root(), source: const UnknownSource(), owner: null);
    _report(PublisherlessPublish(topic: topic.ref));
  }

  void _publish<T>(
    Topic<T> topic,
    T value, {
    required Lineage lineage,
    required MessageSource source,
    required Object? owner,
  }) {
    _cell(topic);
    final envelope = MessageEnvelope<T>.publishedTo(
      topic,
      id: _freshId(),
      payload: value,
      lineage: lineage,
      freshCorrelationId: _freshCorrelationId,
      timestamp: clock.now(),
      source: source,
    );
    final p = _Pending(owner, <TopicRef>[topic.ref], () => _deliver(topic, envelope));
    if (_lifecycle == BusLifecycle.bootstrapping) {
      _startupQueue.add(p);
      _armWindow();
      return;
    }
    if (_delivering > 0) {
      p.chain = <TopicRef>[..._chain, topic.ref];
      if (p.chain.length - 1 == config.maxReentrancyDepth + 1) {
        _report(ReentrancyDepthExceeded(chain: p.chain));
      }
      _deferred.add(p);
      _scheduleDrain();
      return;
    }
    _zone.run(() => _run(p));
  }

  void _run(_Pending p) {
    final saved = _chain;
    _chain = p.chain;
    _delivering++;
    try {
      p.deliver();
    } finally {
      _delivering--;
      _chain = saved;
    }
  }

  void _scheduleDrain() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    _zone.scheduleMicrotask(() {
      _drainScheduled = false;
      _drain();
    });
  }

  void _drain() {
    while (_deferred.isNotEmpty) {
      _run(_deferred.removeFirst());
    }
  }

  void _deliver<T>(Topic<T> topic, MessageEnvelope<T> envelope) {
    final cell = _cell(topic);
    _recorder?._record(topic.ref, envelope);
    if (topic.tracing == Tracing.enabled) {
      for (final o in List<BusObserver>.of(_observers)) {
        if (!ObserverCapability.permits(o.capabilities,
            sensitive: envelope.sensitive)) {
          continue;
        }
        try {
          o.onPublish(topic.ref, envelope, _context);
        } catch (e, st) {
          _report(ObserverThrew(
              observer: o, topic: topic.ref, error: e, stackTrace: st));
        }
      }
    }
    cell.add(envelope);
  }

  void _discard(Object owner) {
    _deferred.removeWhere((p) => identical(p.owner, owner));
    _startupQueue.removeWhere((p) => identical(p.owner, owner));
  }

  void _armWindow() {
    if (!devMode || _windowTimer != null) return;
    _windowTimer = _zone.run(() => Timer(config.startupWindow, () {
          if (_lifecycle == BusLifecycle.bootstrapping) {
            _report(StartNotCalled(
                window: config.startupWindow, queued: _startupQueue.length));
          }
        }));
  }

  // ---------------------------------------------------------- publishers

  Publisher publisher(
    MessageSource source, {
    Set<StateTopic<Object?>> writes = const <StateTopic<Object?>>{},
    Scope scope = Scope.application,
  }) {
    _checkOpen();
    if (source is TopologySource || source is UnknownSource) {
      throw ArgumentError.value(source, 'source', 'not a shell source');
    }
    writes.forEach(_checkName);
    if (writes.isNotEmpty) {
      final claim = ShellClaim(
          source: source,
          scope: scope,
          writes: <TopicRef>{for (final t in writes) t.ref});
      final findings = analyzeTopologyGraph(_graph(claim: claim));
      if (findings.isNotEmpty) {
        throw ClaimRejected(source: source, findings: findings);
      }
    }
    final p = Publisher._(this, source, scope, Set<StateTopic<Object?>>.unmodifiable(writes));
    _publishers.add(p);
    return p;
  }

  // ---------------------------------------------------------- topologies

  TopologyGraph _graph({TopologyDefinition? candidate, ShellClaim? claim}) =>
      TopologyGraph(
        topologies: <TopologyDefinition>[
          for (final a in _active.values) a.definition,
          ?candidate,
        ],
        claims: <ShellClaim>[
          for (final p in _publishers)
            if (p.writes.isNotEmpty)
              ShellClaim(
                  source: p.source,
                  scope: p.scope,
                  writes: <TopicRef>{for (final t in p.writes) t.ref}),
          ?claim,
        ],
      );

  TopologyHandle activate(Topology topology) {
    _checkOpen();
    return _zone.run(() => _activate(topology));
  }

  TopologyHandle _activate(Topology topology) {
    final plan = planOf(topology);
    final definition = plan.definition;
    final existing = _active[definition.topologyId];
    if (existing != null) {
      if (existing.definition == definition) return existing.handle;
      throw TopologyConflict(active: existing.definition, candidate: definition);
    }
    if (_active.length >= config.maxActiveTopologies) {
      throw BusLimitExceeded(
          limit: BusLimit.activeTopologies, max: config.maxActiveTopologies);
    }
    final topics = <String, Topic<Object?>>{};
    for (final s in plan.stages) {
      if (s is ReadStage<Object?>) topics[s.topic.name] = s.topic;
    }
    for (final k in plan.sinks) {
      topics[k.topic.name] = k.topic;
    }
    topics.values.forEach(_checkName);
    final fresh = topics.keys.where((n) => !_cells.containsKey(n)).length;
    if (_cells.length + fresh > config.maxTopics) {
      throw BusLimitExceeded(limit: BusLimit.topics, max: config.maxTopics);
    }
    final findings = analyzeTopologyGraph(_graph(candidate: definition));
    if (findings.isNotEmpty) {
      throw ActivationRejected(
          topologyId: definition.topologyId, findings: findings);
    }
    if (definition.scope == Scope.application &&
        _lifecycle != BusLifecycle.bootstrapping) {
      _report(LateApplicationActivation(topologyId: definition.topologyId));
    }
    final a = _Activation(this, plan);
    _active[definition.topologyId] = a;
    a.wire();
    for (final o in List<BusObserver>.of(_observers)) {
      if (o is! ActivationObserver) continue;
      try {
        o.onActivate(definition.topologyId, definition.scope, _context);
      } catch (e, st) {
        _report(ObserverThrew(observer: o, topic: null, error: e, stackTrace: st));
      }
    }
    return a.handle;
  }

  ModuleScope module(String moduleId, List<Topology> topologies,
      {Duration? gracePeriod}) {
    _checkOpen();
    if (moduleId.isEmpty) throw ArgumentError.value(moduleId, 'moduleId');
    if (topologies.isEmpty) throw ArgumentError.value(topologies, 'topologies');
    for (final t in topologies) {
      if (t.scope != Scope.module) {
        throw ArgumentError.value(t.topologyId, 'topologies', 'not module-scoped');
      }
    }
    final grace = gracePeriod ?? config.moduleScopeGracePeriod;
    if (grace.isNegative) throw ArgumentError.value(grace, 'gracePeriod');
    final existing = _modules[moduleId];
    if (existing != null) {
      final same = existing.gracePeriod == grace &&
          existing.topologies.length == topologies.length &&
          <int>[for (var i = 0; i < topologies.length; i++) i].every((i) =>
              existing.topologies[i].topologyId == topologies[i].topologyId);
      if (!same) throw ArgumentError.value(moduleId, 'moduleId', 'declared differently');
      return existing;
    }
    final m = ModuleScope._(this, moduleId, List<Topology>.unmodifiable(topologies), grace);
    _modules[moduleId] = m;
    return m;
  }

  TopologyGraph toGraph() => _graph();

  // ---------------------------------------------------------- observers

  void addObserver(BusObserver observer) {
    _checkOpen();
    if (_observers.any((o) => identical(o, observer))) {
      throw ArgumentError.value(observer, 'observer', 'already added');
    }
    if (_observers.length >= config.maxObservers) {
      throw BusLimitExceeded(limit: BusLimit.observers, max: config.maxObservers);
    }
    _observers.add(observer);
  }

  bool removeObserver(BusObserver observer) {
    final i = _observers.indexWhere((o) => identical(o, observer));
    if (i < 0) return false;
    _observers.removeAt(i);
    return true;
  }

  // ---------------------------------------------------------- diagnostics

  void reportDiagnostic(ShellDiagnostic diagnostic) => _report(diagnostic);

  void _report(BusDiagnostic d) {
    if (!devMode) return;
    final sink = config.diagnostics;
    _zone.runGuarded(() => sink == null ? print(d) : sink(d));
  }

  // ---------------------------------------------------------- lifecycle

  void start() {
    _checkOpen();
    if (_lifecycle == BusLifecycle.running) return;
    _lifecycle = BusLifecycle.running;
    _windowTimer?.cancel();
    final queue = List<_Pending>.of(_startupQueue);
    _startupQueue.clear();
    _zone.run(() {
      for (final p in queue) {
        _run(p);
      }
    });
  }

  void onShutdown(void Function() callback) {
    _checkOpen();
    _shutdownCallbacks.add(callback);
  }

  void shutdown() {
    if (_lifecycle == BusLifecycle.shutDown) return;
    _zone.run(() {
      if (_lifecycle == BusLifecycle.running) _drain();
      _lifecycle = BusLifecycle.shutDown;
      _windowTimer?.cancel();
      _startupQueue.clear();
      _deferred.clear();
      for (final cb in _shutdownCallbacks.reversed) {
        try {
          cb();
        } catch (e, st) {
          _report(ShutdownCallbackThrew(error: e, stackTrace: st));
        }
      }
      for (final m in _modules.values) {
        m._shutdown();
      }
      for (final a in _active.values.toList().reversed) {
        a.handle.deactivate();
      }
      for (final p in List<Publisher>.of(_publishers)) {
        p.dispose();
      }
      for (final c in _cells.values) {
        c.end();
      }
    });
  }
}

// ------------------------------------------------------------ observe

final class _ObserveStream<T> extends Stream<T> {
  _ObserveStream(this._bus, this._topic);
  final Bus _bus;
  final Topic<T> _topic;

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _bus._zone.run(() {
        if (_bus._lifecycle == BusLifecycle.shutDown) {
          return Stream<T>.empty().listen(onData,
              onError: onError, onDone: onDone, cancelOnError: cancelOnError);
        }
        final t = _topic;
        final dedup = t is StateTopic<T> ? t.dedup : Dedup.none;
        final cell = _bus._cell(t);
        late final StreamSubscription<_D<T>> inner;
        late final StreamController<T> out;
        out = StreamController<T>(
          sync: true,
          onCancel: () {
            cell.observers.remove(out);
            inner.cancel(); // never awaited (ADR-003 item 3)
          },
        );
        cell.observers.add(out);
        // The removal error reaches observed subscriptions through end().
        inner = cell.stream(dedup).listen((d) => out.add(d.payload),
            onError: (Object _) {});
        return out.stream.listen(onData,
            onError: onError, onDone: onDone, cancelOnError: cancelOnError);
      });
}

// ------------------------------------------------------------ publishers

final class Publisher {
  Publisher._(this._bus, this.source, this.scope, this.writes);
  final Bus _bus;
  final MessageSource source;
  final Scope scope;
  final Set<StateTopic<Object?>> writes;
  final Map<StateTopic<Object?>, StateWriter<Object?>> _writers =
      <StateTopic<Object?>, StateWriter<Object?>>{};
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void _checkLive() {
    if (_disposed) throw StateError('the publisher is disposed');
    _bus._checkOpen();
  }

  void publish<T>(MultiWriterTopic<T> topic, T value) {
    _checkLive();
    _bus._publish(topic, value,
        lineage: const Lineage.root(), source: source, owner: this);
  }

  StateWriter<T> writer<T>(StateTopic<T> topic) {
    if (!writes.contains(topic)) {
      throw ArgumentError.value(topic, 'topic', 'not claimed');
    }
    return _writers.putIfAbsent(topic, () => StateWriter<T>._(this, topic))
        as StateWriter<T>;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bus._publishers.remove(this);
    _bus._discard(this);
  }
}

final class StateWriter<T> {
  StateWriter._(this._publisher, this.topic);
  final Publisher _publisher;
  final StateTopic<T> topic;

  void publish(T value) {
    _publisher._checkLive();
    _publisher._bus._publish(topic, value,
        lineage: const Lineage.root(),
        source: _publisher.source,
        owner: _publisher);
  }
}

// ------------------------------------------------------------ handles

final class TopologyHandle {
  TopologyHandle._(this._activation);
  final _Activation _activation;

  String get topologyId => _activation.definition.topologyId;
  Scope get scope => _activation.definition.scope;
  TopologyDefinition get definition => _activation.definition;
  bool get isActive => _activation.active;

  void deactivate() => _activation.deactivate();
}

final class ModuleScope {
  ModuleScope._(this._bus, this.moduleId, this.topologies, this.gracePeriod);
  final Bus _bus;
  final String moduleId;
  final List<Topology> topologies;
  final Duration gracePeriod;
  int _references = 0;
  Timer? _grace;
  final List<TopologyHandle> _handles = <TopologyHandle>[];

  int get references => _references;
  bool get isActive => _handles.isNotEmpty;

  ModuleReference acquire() {
    _bus._checkOpen();
    if (_references == 0) {
      final g = _grace;
      if (g != null) {
        g.cancel();
        _grace = null;
      } else if (_handles.isEmpty) {
        try {
          for (final t in topologies) {
            _handles.add(_bus.activate(t));
          }
        } catch (_) {
          _teardown();
          rethrow;
        }
      }
    }
    _references++;
    return ModuleReference._(this);
  }

  void _release() {
    if (_bus._lifecycle == BusLifecycle.shutDown) return;
    _references--;
    if (_references > 0) return;
    if (gracePeriod == Duration.zero) {
      _teardown();
      return;
    }
    _grace = _bus._zone.run(() => Timer(gracePeriod, () {
          _grace = null;
          _teardown();
        }));
  }

  void _teardown() {
    for (final h in _handles.reversed) {
      h.deactivate();
    }
    _handles.clear();
  }

  void _shutdown() {
    _grace?.cancel();
    _grace = null;
    _references = 0;
    _teardown();
  }
}

final class ModuleReference {
  ModuleReference._(this.scope);
  final ModuleScope scope;
  bool _released = false;

  bool get isReleased => _released;

  void release() {
    if (_released) return;
    _released = true;
    scope._release();
  }
}

// ------------------------------------------------------------ observers

abstract interface class ActivationObserver implements BusObserver {
  void onActivate(String topologyId, Scope scope, ObserveContext context);
}

final class TelemetryObserver implements ActivationObserver {
  TelemetryObserver({
    Set<ObserverCapability> capabilities = const <ObserverCapability>{
      ObserverCapability.observeAll,
    },
  }) : capabilities = Set<ObserverCapability>.unmodifiable(capabilities);

  @override
  final Set<ObserverCapability> capabilities;

  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope,
      ObserveContext context) {
    final causation = envelope.causationId;
    context
        .span(
          topic.name,
          attributes: <String, Object?>{
            'nidana.id': envelope.id,
            'nidana.correlation_id': envelope.correlationId,
            'nidana.causation_id': ?causation,
            'nidana.source': envelope.source.toString(),
            'nidana.payload_type': envelope.payload.runtimeType.toString(),
            if (envelope.sensitive) 'nidana.sensitive': true,
          },
          links: <String>[?causation],
        )
        .end();
  }

  @override
  void onActivate(String topologyId, Scope scope, ObserveContext context) {
    context
        .span(
          'nidana.activation',
          attributes: <String, Object?>{
            'nidana.topology_id': topologyId,
            'nidana.scope': scope.name,
          },
        )
        .end();
  }
}

final class _DefaultContext implements ObserveContext {
  const _DefaultContext();

  @override
  void log(LogLevel level, String message,
      {Map<String, Object?> fields = const <String, Object?>{}}) {
    print('[${level.name}] $message${fields.isEmpty ? '' : ' $fields'}');
  }

  @override
  void metric(String name, double value,
      {Map<String, String> tags = const <String, String>{}}) {}

  @override
  SpanHandle span(String name,
          {Map<String, Object?> attributes = const <String, Object?>{},
          List<String> links = const <String>[]}) =>
      const _NoSpan();
}

final class _NoSpan implements SpanHandle {
  const _NoSpan();
  @override
  void setAttribute(String key, Object? value) {}
  @override
  void end() {}
}
