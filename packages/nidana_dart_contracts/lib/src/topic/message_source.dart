import 'package:meta/meta.dart';

/// Who produced a message (Spec §2.4 `source`). toString() renders the
/// Spec's format: `'topology:<id>'`, `'service:<name>'`,
/// `'page:<routeOrName>'`, `'executor:<name>'`, `'unknown'`.
@immutable
sealed class MessageSource {
  const MessageSource._();

  /// The inverse of toString(); null for any other text (G17).
  static MessageSource? tryParse(String text) => throw UnimplementedError();
}

final class TopologySource extends MessageSource {
  const TopologySource(this.topologyId)
    : assert(topologyId != '', 'topologyId must not be empty'),
      super._();

  final String topologyId;
}

final class ServiceSource extends MessageSource {
  const ServiceSource(this.name)
    : assert(name != '', 'name must not be empty'),
      super._();

  final String name;
}

final class PageSource extends MessageSource {
  const PageSource(this.route)
    : assert(route != '', 'route must not be empty'),
      super._();

  final String route;
}

final class ExecutorSource extends MessageSource {
  const ExecutorSource(this.name)
    : assert(name != '', 'name must not be empty'),
      super._();

  final String name;
}

/// The source of a publisher-less publish (Spec §2.4).
final class UnknownSource extends MessageSource {
  const UnknownSource() : super._();
}
