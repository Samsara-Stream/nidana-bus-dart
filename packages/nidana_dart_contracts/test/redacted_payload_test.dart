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

/// A payload whose hash code is the one it is given.
final class _Hashed {
  const _Hashed(this.code);
  final int code;
  @override
  bool operator ==(Object other) => other is _Hashed && other.code == code;
  @override
  int get hashCode => code;
}

/// A payload of another type with the hash code it is given.
final class _OtherHashed {
  const _OtherHashed(this.code);
  final int code;
  @override
  bool operator ==(Object other) => other is _OtherHashed && other.code == code;
  @override
  int get hashCode => code;
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

  test('G24 the hash is zero-padded to eight lowercase digits, and a '
      'negative hash code gives its low 32 bits', () {
    expect(RedactedPayload.of(const _Hashed(0)).hash, '00000000');
    expect(RedactedPayload.of(const _Hashed(0xabcdef)).hash, '00abcdef');
    expect(RedactedPayload.of(const _Hashed(0xffffffff)).hash, 'ffffffff');
    expect(RedactedPayload.of(const _Hashed(-1)).hash, 'ffffffff');
    expect(RedactedPayload.of(const _Hashed(-0x80000000)).hash, '80000000');
    expect(RedactedPayload.of(const _Hashed(0x100000000)).hash, '00000000');
  });

  test('G24 redacted payloads differ by type name and by hash, each alone, '
      'and are not equal to their rendering', () {
    final RedactedPayload base = RedactedPayload.of(const _Hashed(7));
    expect(base, RedactedPayload.of(const _Hashed(7)));
    expect(base == RedactedPayload.of(const _Hashed(8)), isFalse);
    expect(base == RedactedPayload.of(const _OtherHashed(7)), isFalse);
    final Object rendering = base.toString();
    expect(base == rendering, isFalse);
  });
}
