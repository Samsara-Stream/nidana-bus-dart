// topology-ir@v1's MermaidRenderer (Renderers, Mermaid and Graphviz rules;
// G22), beyond the suite's G22 cases, which compare the seven samples with
// their render/ files: the rules no sample shows, each pinned by the whole
// text of a graph built for it. Durations in every unit, every time stage,
// an anonymous retry, arrows from a repeated input, one topic name of two
// variants and of two type names, each escape in every kind of label, the
// characters left as they are, and no scheduled work.
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';
import 'src/render_support.dart';

String mermaid(TopologyGraph graph) => graph.render(const MermaidRenderer());

void main() {
  test('G22 every sample renders to its render/ .mmd file byte for byte', () {
    final List<String> names = sampleNames();
    expect(names, hasLength(7));
    for (final String name in names) {
      final TopologyGraph graph = sampleGraph(name);
      expect(mermaid(graph), fixtureText('render/$name.mmd'), reason: name);
      expect(
        const MermaidRenderer().render(graph),
        mermaid(graph),
        reason: name,
      );
    }
  });

  test('G22 an empty graph renders as the header line alone', () {
    expect(mermaid(TopologyGraph()), 'flowchart LR\n');
  });

  test('G22 a duration renders in whole seconds, else whole milliseconds, '
      'else microseconds', () {
    for (final (Duration duration, String text) in durationTexts) {
      expect(
        mermaid(delayGraph(duration)),
        contains('\n    p0e0["delay $text"]\n'),
        reason: '$duration',
      );
    }
  });

  test('G22 each time stage renders its combinator and its duration on its '
      'first line', () {
    expect(mermaid(timeStagesGraph()), r'''
flowchart LR
  t0(["t.in<br/>event int"])
  t1(["t.out<br/>event int"])
  subgraph p0["timed<br/>page"]
    p0e0["debounce 1001ms"]
    p0e1["throttle 120s"]
    p0e2["delay 0s"]
    p0e3["sample 1000001us"]
    p0e4["buffer 1ms"]
    p0e5["timeout 1us"]
    p0e6["write"]
  end
  t0 --> p0e0
  p0e0 --> p0e1
  p0e1 --> p0e2
  p0e2 --> p0e3
  p0e3 --> p0e4
  p0e4 --> p0e5
  p0e5 --> p0e6
  p0e6 --> t1
''');
  });

  test('G22 an edge renders its transformer and its retry on lines of their '
      'own, an anonymous reference as (anonymous)', () {
    expect(mermaid(functionsGraph()), r'''
flowchart LR
  t0(["c.query<br/>state String"])
  t1(["c.results<br/>state Results"])
  t2(["c.total<br/>state int"])
  subgraph p0["calls<br/>module"]
    p0e0["switchMap<br/>search<br/>retry (anonymous)"]
    p0e1["switchMap<br/>(anonymous)<br/>retry backoff"]
    p0e2["switchMap<br/>search"]
    p0e3["scan<br/>_add@22518013"]
    p0e4["pairwise"]
    p0e5["write"]
    p0e6["reduceInto<br/>(anonymous)"]
  end
  t0 --> p0e0
  p0e0 --> p0e1
  p0e1 --> p0e2
  p0e2 --> p0e3
  p0e3 --> p0e4
  p0e4 --> p0e5
  p0e5 --> t1
  t0 --> p0e6
  p0e6 --> t2
''');
  });

  test('G22 parts and arrows come in graph order: one arrow per input, a '
      'repeated input repeated, then the sink output, then the claims', () {
    expect(mermaid(arrowsGraph()), r'''
flowchart LR
  t0(["a.out<br/>event int"])
  t1(["a.w<br/>state int"])
  t2(["a.x<br/>state int"])
  t3(["a.x<br/>event int"])
  t4(["a.y<br/>state int"])
  t5(["a.z<br/>replay int"])
  t6(["b.out<br/>event int"])
  subgraph p0["alpha<br/>application"]
    p0e0["map<br/>f"]
    p0e1["write"]
  end
  subgraph p1["arrows<br/>module"]
    p1e0["combine<br/>sum"]
    p1e1["merge"]
    p1e2["write"]
    p1e3["write"]
  end
  s0["page:home<br/>page"]
  s1["service:zeta<br/>application"]
  t0 --> p0e0
  p0e0 --> p0e1
  p0e1 --> t6
  t4 -->|dedup none| p1e0
  t3 --> p1e0
  t3 --> p1e0
  p1e0 --> p1e1
  p1e0 --> p1e1
  t5 --> p1e1
  p1e1 --> p1e2
  p1e2 --> t0
  p1e0 --> p1e3
  p1e3 --> t0
  s0 --> t4
  s1 --> t1
  s1 --> t2
  s1 --> t4
''');
  });

  test('G22 topics of one name and variant but two type names are two nodes, '
      'and each arrow runs to its own', () {
    expect(mermaid(typeNamesGraph()), r'''
flowchart LR
  t0(["a.x<br/>event String"])
  t1(["a.x<br/>event int"])
  subgraph p0["typed<br/>module"]
    p0e0["map<br/>f"]
    p0e1["write"]
  end
  t0 --> p0e0
  p0e0 --> p0e1
  p0e1 --> t1
''');
  });

  test('G22 Mermaid escapes # first, then the quote, the angle brackets and '
      'a newline, in every kind of label, and leaves every other character '
      'as it is', () {
    expect(mermaid(escapesGraph()), r'''
flowchart LR
  t0(["esc.#quot;a#quot;#10;b<br/>state C:\path"])
  t1(["esc.#35;quot;<br/>event Map#lt;String, int#gt;"])
  t2(["esc.\#quot;<br/>event int"])
  t3(["esc.\n<br/>event int"])
  subgraph p0["a&b|c{d}e[f]g'h$i<br/>page"]
    p0e0["map<br/>f#quot;#35;#lt;#gt;\x"]
    p0e1["switchMap<br/>g<br/>retry r#10;q"]
    p0e2["write"]
    p0e3["write"]
  end
  s0["service:a#quot;b#35;c<br/>module"]
  t1 --> p0e0
  p0e0 --> p0e1
  p0e1 --> p0e2
  p0e2 --> t2
  t0 -->|dedup equality| p0e3
  p0e3 --> t3
  s0 --> t0
''');
  });

  test('G22 rendering schedules nothing, and every line ends with a newline '
      'and is indented by two spaces per level', () {
    final List<TopologyGraph> graphs = everyGraph();
    final (List<String> texts, int scheduled) = countingScheduled(
      () => <String>[for (final TopologyGraph g in graphs) mermaid(g)],
    );
    expect(scheduled, 0);
    expect(texts, hasLength(graphs.length));
    for (final String text in texts) {
      expect(text, endsWith('\n'));
      final List<String> lines = text.substring(0, text.length - 1).split('\n');
      expect(lines.first, 'flowchart LR');
      var depth = 1;
      for (final String line in lines.skip(1)) {
        if (line == '  end') {
          depth = 1;
        }
        expect(line, startsWith('  ' * depth), reason: line);
        expect(line[depth * 2], isNot(' '), reason: line);
        if (line.startsWith('  subgraph ')) {
          depth = 2;
        }
      }
    }
  });
}
