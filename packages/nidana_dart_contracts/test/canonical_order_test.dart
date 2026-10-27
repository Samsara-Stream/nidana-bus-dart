// topology-ir@v1's four canonical orders as the shared comparators of
// lib/src/ir/canonical_order.dart, which the IR, the graphs and the findings
// sort by (nidana.model D4). No public library exports them.
import 'dart:io';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/src/ir/canonical_order.dart';
import 'package:test/test.dart';

import 'src/package_files.dart';

TopicRef ref(String name, TopicVariant variant, [String type = 'int']) =>
    TopicRef(name: name, variant: variant, typeName: type);

const TopicVariant state = TopicVariant.state;
const TopicVariant event = TopicVariant.event;
const TopicVariant replay = TopicVariant.replay;

ClaimKey claim(MessageSource source, Scope scope, Iterable<TopicRef> writes) =>
    (source: source, scope: scope, writes: writes);

void main() {
  test('topic references sort by name, then variant as state, event, '
      'replay, then type name by code unit', () {
    final List<TopicRef> refs = <TopicRef>[
      ref('b', state),
      ref('a', replay),
      ref('a', event, 'int'),
      ref('a', event, 'String'),
      ref('a', state, 'int'),
      ref('a', state, 'Cart'),
    ];
    expect(sortedCopy(refs, compareTopicRefs), <TopicRef>[
      ref('a', state, 'Cart'),
      ref('a', state, 'int'),
      ref('a', event, 'String'),
      ref('a', event, 'int'),
      ref('a', replay),
      ref('b', state),
    ]);
    expect(compareTopicRefs(ref('a', event), ref('a', event)), 0);
    expect(
      compareTopicRefs(ref('a.b', replay), ref('a.c', state)),
      lessThan(0),
    );
    expect(compareTopicRefs(ref('a', replay), ref('a', event)), greaterThan(0));
  });

  test('topology ids sort by String.compareTo', () {
    expect(
      sortedCopy(<String>['b', 'B', 'a', 'a-b', 'A'], compareTopologyIds),
      <String>['A', 'B', 'a', 'a-b', 'b'],
    );
  });

  test('message sources sort by their rendering', () {
    expect(
      sortedCopy(const <MessageSource>[
        UnknownSource(),
        TopologySource('a'),
        ServiceSource('b'),
        PageSource('/z'),
        ExecutorSource('nav'),
        ServiceSource('a'),
      ], compareMessageSources),
      const <MessageSource>[
        ExecutorSource('nav'),
        PageSource('/z'),
        ServiceSource('a'),
        ServiceSource('b'),
        TopologySource('a'),
        UnknownSource(),
      ],
    );
  });

  test('claims sort by source, then scope, then writes element by element in '
      'canonical order, a prefix first', () {
    const ServiceSource a = ServiceSource('a');
    const ServiceSource b = ServiceSource('b');
    final TopicRef x = ref('x', state);
    final TopicRef y = ref('y', state);
    final List<ClaimKey> claims = <ClaimKey>[
      claim(b, Scope.application, <TopicRef>[x]),
      claim(a, Scope.page, <TopicRef>[x]),
      claim(a, Scope.application, <TopicRef>[y]),
      claim(a, Scope.application, <TopicRef>[y, x]),
      claim(a, Scope.module, <TopicRef>[x]),
      claim(a, Scope.application, <TopicRef>[x]),
    ];
    expect(
      sortedCopy(claims, compareClaimKeys)
          .map(
            (ClaimKey c) =>
                '${c.source} ${c.scope.name} '
                '${c.writes.map((TopicRef t) => t.name).join(',')}',
          )
          .toList(),
      <String>[
        'service:a application x',
        'service:a application y,x',
        'service:a application y',
        'service:a module x',
        'service:a page x',
        'service:b application x',
      ],
    );
    expect(
      compareClaimKeys(
        claim(a, Scope.application, <TopicRef>[x]),
        claim(a, Scope.application, <TopicRef>[x, y]),
      ),
      lessThan(0),
    );
    expect(
      compareClaimKeys(
        claim(a, Scope.application, <TopicRef>[y, x]),
        claim(a, Scope.application, <TopicRef>{x, y}),
      ),
      0,
    );
    expect(
      compareClaimKeys(
        claim(a, Scope.application, <TopicRef>[y]),
        claim(a, Scope.application, <TopicRef>[x, y]),
      ),
      greaterThan(0),
    );
  });

  test('sortedCopy keeps repeated elements, leaves its argument alone and is '
      'unmodifiable', () {
    final List<int> given = <int>[3, 1, 3, 2];
    final List<int> sorted = sortedCopy(
      given,
      (int a, int b) => a.compareTo(b),
    );
    expect(sorted, <int>[1, 2, 3, 3]);
    expect(given, <int>[3, 1, 3, 2]);
    expect(() => sorted.add(4), throwsUnsupportedError);
  });

  test('topic references and message sources compare equal exactly when they '
      'are equal, and the order is antisymmetric', () {
    final List<TopicRef> refs = <TopicRef>[
      for (final String name in <String>['a', 'a.b', 'b'])
        for (final TopicVariant variant in TopicVariant.values)
          for (final String type in <String>['Cart', 'int'])
            ref(name, variant, type),
    ];
    for (final TopicRef p in refs) {
      for (final TopicRef q in refs) {
        expect(compareTopicRefs(p, q) == 0, p == q, reason: '$p, $q');
        expect(
          compareTopicRefs(p, q).sign,
          -compareTopicRefs(q, p).sign,
          reason: '${p.name}, ${q.name}',
        );
      }
    }
    const List<MessageSource> sources = <MessageSource>[
      ExecutorSource('a'),
      PageSource('a'),
      ServiceSource('a'),
      ServiceSource('a-b'),
      TopologySource('a'),
      UnknownSource(),
    ];
    for (final MessageSource p in sources) {
      for (final MessageSource q in sources) {
        expect(compareMessageSources(p, q) == 0, p == q, reason: '$p, $q');
        expect(
          compareMessageSources(p, q).sign,
          -compareMessageSources(q, p).sign,
          reason: '$p, $q',
        );
      }
    }
  });

  test('claims that differ only in the order of their writes compare equal, '
      'and the order is antisymmetric', () {
    final TopicRef x = ref('x', state);
    final TopicRef y = ref('y', event);
    final List<ClaimKey> claims = <ClaimKey>[
      for (final MessageSource source in const <MessageSource>[
        ServiceSource('a'),
        PageSource('a'),
      ])
        for (final Scope scope in Scope.values)
          for (final List<TopicRef> writes in <List<TopicRef>>[
            <TopicRef>[],
            <TopicRef>[x],
            <TopicRef>[x, y],
            <TopicRef>[y, x],
            <TopicRef>[y],
          ])
            claim(source, scope, writes),
    ];
    for (final ClaimKey p in claims) {
      for (final ClaimKey q in claims) {
        expect(
          compareClaimKeys(p, q).sign,
          -compareClaimKeys(q, p).sign,
          reason: '${p.source} ${p.scope}, ${q.source} ${q.scope}',
        );
      }
    }
    expect(
      compareClaimKeys(
        claim(const PageSource('a'), Scope.page, <TopicRef>[]),
        claim(const PageSource('a'), Scope.page, const <TopicRef>[]),
      ),
      0,
    );
    expect(
      compareClaimKeys(
        claim(const PageSource('a'), Scope.page, <TopicRef>[]),
        claim(const PageSource('a'), Scope.page, <TopicRef>[x]),
      ),
      lessThan(0),
    );
  });

  test('sortedCopy sorts any iterable, the empty one included', () {
    expect(sortedCopy(<int>{3, 1, 2}, (int a, int b) => a.compareTo(b)), <int>[
      1,
      2,
      3,
    ]);
    expect(
      sortedCopy(
        <int>[3, 1, 2].map((int n) => -n),
        (int a, int b) => a.compareTo(b),
      ),
      <int>[-3, -2, -1],
    );
    expect(sortedCopy(<int>[], (int a, int b) => a.compareTo(b)), isEmpty);
  });

  test('canonical_order.dart imports the topic model and nothing else, so '
      'definition.dart can import it', () {
    final File library = File(
      '${packageDirectory().path}/lib/src/ir/canonical_order.dart',
    );
    final List<String> directives = <String>[
      for (final Match m in RegExp(
        r'^(?:import|export|part)\b[^;]*;',
        multiLine: true,
      ).allMatches(library.readAsStringSync()))
        m[0]!,
    ];
    expect(directives, <String>[
      "import '../topic/message_source.dart';",
      "import '../topic/scope.dart';",
      "import '../topic/topic.dart';",
    ]);
  });

  test('no library under lib/src/ir/ imports or exports lib/src/graph/', () {
    final RegExp graph = RegExp(
      r"^(import|export)\s+'[^']*graph/",
      multiLine: true,
    );
    final Directory ir = Directory('${packageDirectory().path}/lib/src/ir');
    expect(<String>[
      for (final FileSystemEntity f in ir.listSync(recursive: true))
        if (f is File && graph.hasMatch(f.readAsStringSync())) f.path,
    ], isEmpty);
  });
}
