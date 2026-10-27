import 'package:meta/meta.dart';

/// Who produced a message (Spec §2.4 `source`). toString() renders the
/// Spec's format: `'topology:<id>'`, `'service:<name>'`,
/// `'page:<routeOrName>'`, `'executor:<name>'`, `'unknown'`.
@immutable
sealed class MessageSource {
  const MessageSource._();

  /// The inverse of toString(); null for any other text (G17).
  static MessageSource? tryParse(String text) {
    if (text == 'unknown') {
      return const UnknownSource();
    }
    final int colon = text.indexOf(':');
    if (colon < 0 || colon == text.length - 1) {
      return null;
    }
    final String field = text.substring(colon + 1);
    return switch (text.substring(0, colon)) {
      'topology' => TopologySource(field),
      'service' => ServiceSource(field),
      'page' => PageSource(field),
      'executor' => ExecutorSource(field),
      _ => null,
    };
  }

  @override
  String toString() => switch (this) {
    TopologySource(:final String topologyId) => 'topology:$topologyId',
    ServiceSource(:final String name) => 'service:$name',
    PageSource(:final String route) => 'page:$route',
    ExecutorSource(:final String name) => 'executor:$name',
    UnknownSource() => 'unknown',
  };

  // Equal exactly when variant and field are (G17): the rendering names the
  // variant before its first colon and the field after it.
  @override
  bool operator ==(Object other) =>
      other is MessageSource && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

final class TopologySource extends MessageSource {
  const TopologySource(this.topologyId) // non-empty
    : assert(topologyId != '', 'topologyId must not be empty'),
      super._();

  final String topologyId;
}

final class ServiceSource extends MessageSource {
  const ServiceSource(this.name) // non-empty
    : assert(name != '', 'name must not be empty'),
      super._();

  final String name;
}

final class PageSource extends MessageSource {
  const PageSource(this.route) // non-empty
    : assert(route != '', 'route must not be empty'),
      super._();

  final String route;
}

final class ExecutorSource extends MessageSource {
  const ExecutorSource(this.name) // non-empty
    : assert(name != '', 'name must not be empty'),
      super._();

  final String name;
}

/// The source of a publisher-less publish (Spec §2.4).
final class UnknownSource extends MessageSource {
  const UnknownSource() : super._();
}
