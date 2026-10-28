// topic-model@v1's redacted payloads, beyond the cases of its conformance
// suite, which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

/// A payload whose hash code is wider than 32 bits.
final class _Wide {
  const _Wide();
  @override
  bool operator ==(Object other) => other is _Wide;
  @override
  int get hashCode => 0x71234abcd;
}

void main() {
  test('G24 the hash keeps the low 32 bits of a hash code wider than 32 '
      'bits', () {
    expect(RedactedPayload.of(const _Wide()).hash, '1234abcd');
  });

  test('G24 a payload of a core type redacts to its runtime type and eight '
      'lowercase hexadecimal digits', () {
    for (final Object? payload in <Object?>[
      'card-4242-4242',
      42,
      <int>[1, 2],
      <String, String>{'token': 'tok-secret'},
      null,
    ]) {
      final RedactedPayload redacted = RedactedPayload.of(payload);
      expect(redacted.typeName, payload.runtimeType.toString());
      expect(redacted.hash, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(
        redacted.toString(),
        '<redacted ${redacted.typeName} #${redacted.hash}>',
      );
    }
    expect(RedactedPayload.of('card-4242-4242').typeName, 'String');
    expect(
      RedactedPayload.of(<String, String>{'token': 'tok-secret'}).toString(),
      isNot(contains('tok-secret')),
    );
  });

  test('G24 redacted payloads of equal payloads are one set element', () {
    final String card = <String>['card-4242-4242'].single;
    expect(<RedactedPayload>{
      RedactedPayload.of(card),
      RedactedPayload.of(card),
      RedactedPayload.of('other'),
    }, hasLength(2));
  });
}
