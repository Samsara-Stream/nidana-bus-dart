import 'package:meta/meta.dart';

/// A sensitive payload as diagnostics, recorders and devtools show it: its
/// type and a truncated hash (Spec §9.2 item 2).
@immutable
final class RedactedPayload {
  // RedactedPayload.of constructs through this once nidana.model.8 lands it.
  // ignore: unused_element
  const RedactedPayload._(this.typeName, this.hash);

  /// typeName is payload.runtimeType.toString(); hash is the low 32 bits of
  /// payload.hashCode as eight lowercase hexadecimal digits.
  factory RedactedPayload.of(Object? payload) => throw UnimplementedError();

  final String typeName;
  final String hash;
}
