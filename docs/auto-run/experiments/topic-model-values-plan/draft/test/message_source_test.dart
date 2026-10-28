// topic-model@v1's message sources, beyond the cases of its conformance
// suite, which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('G17 tryParse splits at the first colon and keeps all the rest, '
      'white space and colons included, as the field', () {
    expect(
      MessageSource.tryParse('topology: spaced'),
      const TopologySource(' spaced'),
    );
    expect(MessageSource.tryParse('executor::'), const ExecutorSource(':'));
    expect(MessageSource.tryParse('service:a:b'), const ServiceSource('a:b'));
  });

  test('G17 tryParse returns null for padded, misspelt or truncated '
      'renderings', () {
    for (final String text in <String>[
      ' service:a',
      'service :a',
      'unknown ',
      'UNKNOWN',
      'page',
      'executor:',
      'topology',
    ]) {
      expect(MessageSource.tryParse(text), isNull, reason: text);
    }
  });

  test('G17 sources built apart are one set element per variant and '
      'field', () {
    final String name = <String>['auth'].single;
    final Set<MessageSource> sources = <MessageSource>{
      ServiceSource(name),
      ServiceSource(name),
      ExecutorSource(name),
      PageSource(name),
      TopologySource(name),
      const UnknownSource(),
      UnknownSource(),
    };
    expect(sources, hasLength(5));
    expect(ServiceSource(name).hashCode, const ServiceSource('auth').hashCode);
  });
}
