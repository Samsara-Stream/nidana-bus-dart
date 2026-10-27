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

  test('G17 a field with colons and white space renders after the variant '
      'and parses back to an equal source, whatever the variant', () {
    for (final MessageSource source in const <MessageSource>[
      TopologySource(' a:b: '),
      ServiceSource('::'),
      PageSource('/users/:id/edit'),
      ExecutorSource('unknown'),
      ExecutorSource('page:x'),
    ]) {
      final MessageSource? parsed = MessageSource.tryParse(source.toString());
      expect(parsed, source);
      expect(parsed.runtimeType, source.runtimeType);
    }
    expect(
      const PageSource('/users/:id/edit').toString(),
      'page:/users/:id/edit',
    );
  });

  test('G17 a service whose name reads like a rendering is not the source '
      'that rendering parses to', () {
    expect(
      MessageSource.tryParse('service:executor:x'),
      const ServiceSource('executor:x'),
    );
    expect(
      const ServiceSource('executor:x') == const ExecutorSource('x'),
      isFalse,
    );
  });

  test('G17 a source is never equal to a value that is not a source, '
      'including its own rendering', () {
    final Object rendering = 'service:a';
    expect(const ServiceSource('a') == rendering, isFalse);
    final Object unknown = 'unknown';
    expect(const UnknownSource() == unknown, isFalse);
  });
}
