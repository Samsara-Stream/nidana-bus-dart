part of 'bus.dart';

// ------------------------------------------------------------ diagnostics

@immutable
sealed class BusDiagnostic {
  const BusDiagnostic();
}

final class PublisherlessPublish extends BusDiagnostic {
  const PublisherlessPublish({required this.topic});
  final TopicRef topic;
  @override
  String toString() => 'PublisherlessPublish(${topic.name})';
}

final class ReentrancyDepthExceeded extends BusDiagnostic {
  ReentrancyDepthExceeded({required List<TopicRef> chain})
      : chain = List<TopicRef>.unmodifiable(chain);
  final List<TopicRef> chain;
  @override
  String toString() =>
      'ReentrancyDepthExceeded(${chain.map((t) => t.name).join(' > ')})';
}

final class ObserverThrew extends BusDiagnostic {
  const ObserverThrew({
    required this.observer,
    required this.topic,
    required this.error,
    required this.stackTrace,
  });
  final BusObserver observer;
  final TopicRef? topic;
  final Object error;
  final StackTrace stackTrace;
  @override
  String toString() => 'ObserverThrew(${observer.runtimeType}, ${topic?.name}, $error)';
}

final class StartNotCalled extends BusDiagnostic {
  const StartNotCalled({required this.window, required this.queued});
  final Duration window;
  final int queued;
  @override
  String toString() => 'StartNotCalled($window, $queued queued)';
}

final class PipelineTerminated extends BusDiagnostic {
  const PipelineTerminated({
    required this.topologyId,
    required this.sink,
    required this.error,
    required this.stackTrace,
  });
  final String topologyId;
  final TopicRef sink;
  final Object error;
  final StackTrace stackTrace;
  @override
  String toString() => 'PipelineTerminated($topologyId, ${sink.name}, $error)';
}

final class TopicLimitExceeded extends BusDiagnostic {
  const TopicLimitExceeded({required this.topic, required this.maxTopics});
  final TopicRef topic;
  final int maxTopics;
  @override
  String toString() => 'TopicLimitExceeded(${topic.name}, $maxTopics)';
}

final class LateApplicationActivation extends BusDiagnostic {
  const LateApplicationActivation({required this.topologyId});
  final String topologyId;
  @override
  String toString() => 'LateApplicationActivation($topologyId)';
}

final class ShutdownCallbackThrew extends BusDiagnostic {
  const ShutdownCallbackThrew({required this.error, required this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  @override
  String toString() => 'ShutdownCallbackThrew($error)';
}

abstract base class ShellDiagnostic extends BusDiagnostic {
  const ShellDiagnostic();
  String get origin;
}

// ------------------------------------------------------------ errors

sealed class BusError extends Error {}

final class ActivationRejected extends BusError {
  ActivationRejected({required this.topologyId, required List<TopologyFinding> findings})
      : findings = List<TopologyFinding>.unmodifiable(findings);
  final String topologyId;
  final List<TopologyFinding> findings;
  @override
  String toString() => 'ActivationRejected($topologyId, $findings)';
}

final class ClaimRejected extends BusError {
  ClaimRejected({required this.source, required List<TopologyFinding> findings})
      : findings = List<TopologyFinding>.unmodifiable(findings);
  final MessageSource source;
  final List<TopologyFinding> findings;
  @override
  String toString() => 'ClaimRejected($source, $findings)';
}

final class TopologyConflict extends BusError {
  TopologyConflict({required this.active, required this.candidate});
  final TopologyDefinition active;
  final TopologyDefinition candidate;
  String get topologyId => active.topologyId;
  @override
  String toString() => 'TopologyConflict($topologyId)';
}

final class TopicCollision extends BusError {
  TopicCollision({required this.registered, required this.requested});
  final Topic<Object?> registered;
  final Topic<Object?> requested;
  String get name => registered.name;
  @override
  String toString() => 'TopicCollision($registered, $requested)';
}

enum BusLimit { topics, activeTopologies, observers }

final class BusLimitExceeded extends BusError {
  BusLimitExceeded({required this.limit, required this.max});
  final BusLimit limit;
  final int max;
  @override
  String toString() => 'BusLimitExceeded(${limit.name}, $max)';
}

@immutable
final class TopicRemoved implements Exception {
  const TopicRemoved(this.topic);
  final TopicRef topic;
  @override
  String toString() => 'TopicRemoved(${topic.name})';
}
