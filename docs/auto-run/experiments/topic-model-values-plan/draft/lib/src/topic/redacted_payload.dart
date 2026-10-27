import 'package:meta/meta.dart';

/// A sensitive payload as diagnostics, recorders and devtools show it: its
/// type and a truncated hash (Spec §9.2 item 2).
@immutable
final class RedactedPayload {
  const RedactedPayload._(this.typeName, this.hash);

  /// typeName is payload.runtimeType.toString(); hash is the low 32 bits of
  /// payload.hashCode as eight lowercase hexadecimal digits.
  factory RedactedPayload.of(Object? payload) => RedactedPayload._(
    payload.runtimeType.toString(),
    payload.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0'),
  );

  final String typeName;
  final String hash;

  // typeName and hash
  @override
  bool operator ==(Object other) =>
      other is RedactedPayload &&
      other.typeName == typeName &&
      other.hash == hash;

  @override
  int get hashCode => Object.hash(typeName, hash);

  // '<redacted {typeName} #{hash}>'
  @override
  String toString() => '<redacted $typeName #$hash>';
}
