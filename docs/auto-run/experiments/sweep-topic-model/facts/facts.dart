// Runtime facts behind S151, the end-of-nidana.model governance sweep of
// topic-model@v1, read off the shipped package (packages/nidana_dart_contracts)
// rather than a stand-in. run.sh runs it from the repository root, so the
// workspace's package configuration resolves the package import.
//
//   S: a short payload rendering inside its redaction (items S124a).
//   W: redacting an envelope that is already redacted (S124b).
//   P: what the observer interfaces and Lineage.combine are (S124c).
//   E: redactions of payloads that are equal but of two runtime types (S125a).
//   N: an envelope whose payload is NaN, and how Dart's own collections and
//      records treat a value that is not equal to itself (S125b).
//   R: the renderings of Topic, TopicRef and Lineage (S125c).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final DateTime _at = DateTime.utc(2026, 10, 28);

MessageEnvelope<T> _envelope<T>(T payload, {bool sensitive = false}) =>
    MessageEnvelope<T>(
      id: 'e-1',
      payload: payload,
      correlationId: 'c-1',
      timestamp: _at,
      source: const ServiceSource('probe'),
      sensitive: sensitive,
    );

String _attempt(Object? Function() body) {
  try {
    return 'returns ${body()}';
  } on Object catch (e) {
    return 'throws ${e.runtimeType}';
  }
}

void main() {
  print('S1 RedactedPayload.of(\'String\') = ${RedactedPayload.of('String')}');
  print('S2 its rendering contains the payload\'s rendering: '
      '${RedactedPayload.of('String').toString().contains('String')}');
  print('S3 RedactedPayload.of(\'a\') contains \'a\': '
      '${RedactedPayload.of('a').toString().contains('a')}');
  final MessageEnvelope<String> shortSecret =
      _envelope<String>('redacted', sensitive: true);
  print('S4 sensitive envelope with payload \'redacted\' renders it inside: '
      '${shortSecret.toString().contains('redacted')}');

  final MessageEnvelope<String> secret =
      _envelope<String>('SECRET', sensitive: true);
  final MessageEnvelope<Object?> once = secret.redacted();
  final MessageEnvelope<Object?> twice = once.redacted();
  print('W1 secret.toString() payload part: '
      '${secret.toString().split(', ')[1]}');
  print('W2 secret.redacted().payload = ${once.payload} '
      '(${once.payload.runtimeType}); sensitive ${once.sensitive}');
  print('W3 secret.redacted().toString() payload part: '
      '${once.toString().split(', ')[1]}');
  print('W4 secret.redacted().redacted().payload = ${twice.payload}');
  print('W5 redacted() twice keeps the type name String: '
      '${twice.payload.toString().contains('String')}');

  print('P1 Lineage.combine([]) ${_attempt(() => Lineage.combine(
        const <Lineage>[],
        trigger: 0,
        freshCorrelationId: () => 'fresh',
      ))}');
  print('P2 Lineage.combine([root], trigger: 1) ${_attempt(() => Lineage.combine(
        const <Lineage>[Lineage.root()],
        trigger: 1,
        freshCorrelationId: () => 'fresh',
      ))}');
  print('P3 RangeError is an ArgumentError: '
      '${RangeError('x') is ArgumentError}');

  final RedactedPayload ofInt = RedactedPayload.of(1);
  final RedactedPayload ofDouble = RedactedPayload.of(1.0);
  print('E1 1 == 1.0: ${1 == 1.0}; hash codes equal: '
      '${1.hashCode == 1.0.hashCode}');
  print('E2 RedactedPayload.of(1) = $ofInt; RedactedPayload.of(1.0) = '
      '$ofDouble');
  print('E3 RedactedPayload.of(1) == RedactedPayload.of(1.0): '
      '${ofInt == ofDouble}');

  final MessageEnvelope<double> nan = _envelope<double>(double.nan);
  final MessageEnvelope<double> nanAgain = _envelope<double>(double.nan);
  print('N1 identical(nan, nan): ${identical(nan, nan)}; nan == nan: '
      '${nan == nan}; nan == nanAgain: ${nan == nanAgain}');
  print('N2 nan.hashCode == nanAgain.hashCode: '
      '${nan.hashCode == nanAgain.hashCode}');
  final Set<MessageEnvelope<double>> set = <MessageEnvelope<double>>{nan};
  print('N3 {nan}.contains(nan): ${set.contains(nan)}');
  print('N4 {nan}.remove(nan): ${set.remove(nan)}; length after: '
      '${set.length}');
  print('N5 [nan].contains(nan): ${<Object>[nan].contains(nan)}; '
      'indexOf: ${<Object>[nan].indexOf(nan)}');
  final Map<MessageEnvelope<double>, int> map = <MessageEnvelope<double>, int>{
    nan: 1,
  };
  print('N6 {nan: 1}[nan]: ${map[nan]}');
  print('N7 double.nan == double.nan: ${double.nan == double.nan}; '
      '{double.nan}.contains(double.nan): '
      '${<double>{double.nan}.contains(double.nan)}; '
      '[double.nan].contains(double.nan): '
      '${<double>[double.nan].contains(double.nan)}');
  final (double,) record = (double.nan,);
  print('N8 record (nan,) == itself: ${record == record}; == (nan,): '
      '${record == (double.nan,)}; {record}.contains(record): '
      '${<(double,)>{record}.contains(record)}');
  const _Never never = _Never();
  final (_Never,) neverRecord = (never,);
  print('N9 a value never == itself: ${never == never}; in a record, the '
      'record == itself: ${neverRecord == neverRecord}; == (never,): '
      '${neverRecord == (never,)}');
  final MessageEnvelope<Object?> sensitiveNan =
      _envelope<double>(double.nan, sensitive: true).redacted();
  print('N10 a redacted NaN envelope == itself: '
      '${sensitiveNan == sensitiveNan}');

  const StateTopic<int> topic = StateTopic<int>(name: 'a.count', initial: 0);
  print('R1 Topic: $topic');
  print('R2 TopicRef: ${topic.ref}');
  print('R3 Lineage: ${const Lineage.root()}');
  print('R4 MessageSource: ${const TopologySource('flow')}');
}

/// A value whose == is false even against itself, like double.nan.
final class _Never {
  const _Never();
  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) => false;
}
