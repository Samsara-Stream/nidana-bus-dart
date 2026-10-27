// topology-ir@v1's GraphvizRenderer (Renderers, Mermaid and Graphviz rules;
// G22), beyond the suite's G22 cases, which compare the seven samples with
// their render/ files: the rules no sample shows, each pinned by the whole
// text of a graph built for it. Durations in every unit, every time stage,
// an anonymous retry, arrows from a repeated input, one topic name of two
// variants, each escape in every kind of label, the characters left as they
// are, and no scheduled work.
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';
import 'src/render_support.dart';

String graphviz(TopologyGraph graph) => graph.render(const GraphvizRenderer());

void main() {
  test('G22 every sample renders to its render/ .dot file byte for byte', () {
    final List<String> names = sampleNames();
    expect(names, hasLength(7));
    for (final String name in names) {
      final TopologyGraph graph = sampleGraph(name);
      expect(graphviz(graph), fixtureText('render/$name.dot'), reason: name);
      expect(
        const GraphvizRenderer().render(graph),
        graphviz(graph),
        reason: name,
      );
    }
  });

  test('G22 an empty graph renders as the header and the footer alone', () {
    expect(
      graphviz(TopologyGraph()),
      'digraph topologies {\n  rankdir=LR;\n}\n',
    );
  });

  test('G22 a duration renders in whole seconds, else whole milliseconds, '
      'else microseconds', () {
    for (final (Duration duration, String text) in durationTexts) {
      expect(
        graphviz(delayGraph(duration)),
        contains('\n    p0e0 [shape=box, label="delay $text"];\n'),
        reason: '$duration',
      );
    }
  });

  test('G22 each time stage renders its combinator and its duration on its '
      'first line', () {
    expect(graphviz(timeStagesGraph()), r'''
digraph topologies {
  rankdir=LR;
  t0 [shape=ellipse, label="t.in\nevent int"];
  t1 [shape=ellipse, label="t.out\nevent int"];
  subgraph cluster_p0 {
    label="timed\npage";
    p0e0 [shape=box, label="debounce 1001ms"];
    p0e1 [shape=box, label="throttle 120s"];
    p0e2 [shape=box, label="delay 0s"];
    p0e3 [shape=box, label="sample 1000001us"];
    p0e4 [shape=box, label="buffer 1ms"];
    p0e5 [shape=box, label="timeout 1us"];
    p0e6 [shape=box, label="write"];
  }
  t0 -> p0e0;
  p0e0 -> p0e1;
  p0e1 -> p0e2;
  p0e2 -> p0e3;
  p0e3 -> p0e4;
  p0e4 -> p0e5;
  p0e5 -> p0e6;
  p0e6 -> t1;
}
''');
  });

  test('G22 an edge renders its transformer and its retry on lines of their '
      'own, an anonymous reference as (anonymous)', () {
    expect(graphviz(functionsGraph()), r'''
digraph topologies {
  rankdir=LR;
  t0 [shape=ellipse, label="c.query\nstate String"];
  t1 [shape=ellipse, label="c.results\nstate Results"];
  t2 [shape=ellipse, label="c.total\nstate int"];
  subgraph cluster_p0 {
    label="calls\nmodule";
    p0e0 [shape=box, label="switchMap\nsearch\nretry (anonymous)"];
    p0e1 [shape=box, label="switchMap\n(anonymous)\nretry backoff"];
    p0e2 [shape=box, label="switchMap\nsearch"];
    p0e3 [shape=box, label="scan\n_add@22518013"];
    p0e4 [shape=box, label="pairwise"];
    p0e5 [shape=box, label="write"];
    p0e6 [shape=box, label="reduceInto\n(anonymous)"];
  }
  t0 -> p0e0;
  p0e0 -> p0e1;
  p0e1 -> p0e2;
  p0e2 -> p0e3;
  p0e3 -> p0e4;
  p0e4 -> p0e5;
  p0e5 -> t1;
  t0 -> p0e6;
  p0e6 -> t2;
}
''');
  });

  test('G22 parts and arrows come in graph order: one arrow per input, a '
      'repeated input repeated, then the sink output, then the claims', () {
    expect(graphviz(arrowsGraph()), r'''
digraph topologies {
  rankdir=LR;
  t0 [shape=ellipse, label="a.out\nevent int"];
  t1 [shape=ellipse, label="a.w\nstate int"];
  t2 [shape=ellipse, label="a.x\nstate int"];
  t3 [shape=ellipse, label="a.x\nevent int"];
  t4 [shape=ellipse, label="a.y\nstate int"];
  t5 [shape=ellipse, label="a.z\nreplay int"];
  t6 [shape=ellipse, label="b.out\nevent int"];
  subgraph cluster_p0 {
    label="alpha\napplication";
    p0e0 [shape=box, label="map\nf"];
    p0e1 [shape=box, label="write"];
  }
  subgraph cluster_p1 {
    label="arrows\nmodule";
    p1e0 [shape=box, label="combine\nsum"];
    p1e1 [shape=box, label="merge"];
    p1e2 [shape=box, label="write"];
    p1e3 [shape=box, label="write"];
  }
  s0 [shape=box, style=rounded, label="page:home\npage"];
  s1 [shape=box, style=rounded, label="service:zeta\napplication"];
  t0 -> p0e0;
  p0e0 -> p0e1;
  p0e1 -> t6;
  t4 -> p1e0 [label="dedup none"];
  t3 -> p1e0;
  t3 -> p1e0;
  p1e0 -> p1e1;
  p1e0 -> p1e1;
  t5 -> p1e1;
  p1e1 -> p1e2;
  p1e2 -> t0;
  p1e0 -> p1e3;
  p1e3 -> t0;
  s0 -> t4;
  s1 -> t1;
  s1 -> t2;
  s1 -> t4;
}
''');
  });

  test(r'G22 Graphviz escapes \ first, then the quote and a newline, in every '
      'kind of label, and leaves every other character as it is', () {
    expect(graphviz(escapesGraph()), r'''
digraph topologies {
  rankdir=LR;
  t0 [shape=ellipse, label="esc.\"a\"\nb\nstate C:\\path"];
  t1 [shape=ellipse, label="esc.#quot;\nevent Map<String, int>"];
  t2 [shape=ellipse, label="esc.\\\"\nevent int"];
  t3 [shape=ellipse, label="esc.\\n\nevent int"];
  subgraph cluster_p0 {
    label="a&b|c{d}e[f]g'h$i\npage";
    p0e0 [shape=box, label="map\nf\"#<>\\x"];
    p0e1 [shape=box, label="switchMap\ng\nretry r\nq"];
    p0e2 [shape=box, label="write"];
    p0e3 [shape=box, label="write"];
  }
  s0 [shape=box, style=rounded, label="service:a\"b#c\nmodule"];
  t1 -> p0e0;
  p0e0 -> p0e1;
  p0e1 -> p0e2;
  p0e2 -> t2;
  t0 -> p0e3 [label="dedup equality"];
  p0e3 -> t3;
  s0 -> t0;
}
''');
  });

  test('G22 rendering schedules nothing, and every line ends with a newline '
      'and is indented by two spaces per level', () {
    final List<TopologyGraph> graphs = everyGraph();
    final (List<String> texts, int scheduled) = countingScheduled(
      () => <String>[for (final TopologyGraph g in graphs) graphviz(g)],
    );
    expect(scheduled, 0);
    expect(texts, hasLength(graphs.length));
    for (final String text in texts) {
      expect(text, endsWith('\n'));
      final List<String> lines = text.substring(0, text.length - 1).split('\n');
      expect(lines.first, 'digraph topologies {');
      expect(lines.last, '}');
      var depth = 1;
      for (final String line in lines.skip(1).take(lines.length - 2)) {
        if (line == '  }') {
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
