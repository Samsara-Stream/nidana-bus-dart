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

  test('no library under lib/src/ir/ imports or exports lib/src/graph/', () {
    final RegExp graph = RegExp(
      r"^(import|export)\s+'[^']*graph/",
      multiLine: true,
    );
    final Directory ir = Directory('${packageDirectory().path}/lib/src/ir');
    expect(<String>[
      for (final FileSystemEntity f in ir.listSync())
        if (f is File && graph.hasMatch(f.readAsStringSync())) f.path,
    ], isEmpty);
  });
}
