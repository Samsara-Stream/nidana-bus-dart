// Surface of bus-api@v2, observers, the telemetry observer, diagnostics and
// errors. The switches are exhaustive, so a variant added to a sealed
// family fails this set.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

final class Lifecycle implements ActivationObserver {
  @override
  Set<ObserverCapability> get capabilities =>
      const <ObserverCapability>{ObserverCapability.observeAll};

  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope,
      ObserveContext context) {}

  @override
  void onActivate(String topologyId, Scope scope, ObserveContext context) =>
      context.log(LogLevel.info, 'activated $topologyId ($scope)');
}

final class RouteWarning extends ShellDiagnostic {
  const RouteWarning(this.route);
  final String route;

  @override
  String get origin => 'executor:example';
}

void observers(Bus bus) {
  final TelemetryObserver telemetry = TelemetryObserver();
  final TelemetryObserver sensitive = TelemetryObserver(
    capabilities: <ObserverCapability>{
      ObserverCapability.observeAll,
      ObserverCapability.observeSensitive,
    },
  );
  final Set<ObserverCapability> capabilities = telemetry.capabilities;
  final ActivationObserver asActivation = telemetry;
  final BusObserver asObserver = sensitive;
  bus.addObserver(telemetry);
  bus.addObserver(Lifecycle());
  final bool removed = bus.removeObserver(telemetry);
  bus.reportDiagnostic(const RouteWarning('/cart'));
  print(<Object?>[capabilities, asActivation, asObserver, removed]);
}

String describe(BusDiagnostic diagnostic) => switch (diagnostic) {
      PublisherlessPublish(:final TopicRef topic) => 'unknown source ${topic.name}',
      ReentrancyDepthExceeded(:final List<TopicRef> chain) => 'chain $chain',
      ObserverThrew(
        :final BusObserver observer,
        :final TopicRef? topic,
        :final Object error,
        :final StackTrace stackTrace,
      ) =>
        'observer $observer on $topic: $error $stackTrace',
      StartNotCalled(:final Duration window, :final int queued) =>
        'start not called in $window, $queued queued',
      PipelineTerminated(
        :final String topologyId,
        :final TopicRef sink,
        :final Object error,
        :final StackTrace stackTrace,
      ) =>
        '$topologyId ended at ${sink.name}: $error $stackTrace',
      TopicLimitExceeded(:final TopicRef topic, :final int maxTopics) =>
        '${topic.name} beyond $maxTopics',
      LateApplicationActivation(:final String topologyId) => 'late $topologyId',
      ShutdownCallbackThrew(:final Object error, :final StackTrace stackTrace) =>
        'shutdown callback: $error $stackTrace',
      ShellDiagnostic(:final String origin) => 'from $origin',
    };

String explain(BusError error) => switch (error) {
      ActivationRejected(
        :final String topologyId,
        :final List<TopologyFinding> findings,
      ) =>
        '$topologyId: $findings',
      ClaimRejected(:final MessageSource source, :final List<TopologyFinding> findings) =>
        '$source: $findings',
      TopologyConflict(
        :final String topologyId,
        :final TopologyDefinition active,
        :final TopologyDefinition candidate,
      ) =>
        '$topologyId: $active $candidate',
      TopicCollision(
        :final String name,
        :final Topic<Object?> registered,
        :final Topic<Object?> requested,
      ) =>
        '$name: $registered $requested',
      BusLimitExceeded(:final BusLimit limit, :final int max) => '$limit $max',
    };

String limit(BusLimit limit) => switch (limit) {
      BusLimit.topics => 'topics',
      BusLimit.activeTopologies => 'active topologies',
      BusLimit.observers => 'observers',
    };

void removal(Object error) {
  if (error is TopicRemoved) {
    final TopicRef topic = error.topic;
    final Exception asException = error;
    print(<Object?>[topic, asException]);
  }
}
