// Which render/ goldens the package's renderers do not reproduce, and where:
// each sample decoded from its valid/ document (G20 gives the sample back),
// rendered by MermaidRenderer and GraphvizRenderer, and compared with its
// render/ files. run.sh copies it to a workspace copy's root and runs it
// there, so that it renders with that copy's (possibly seeded) package.
import 'dart:convert';
import 'dart:io';

import 'package:nidana_dart_contracts/topology_ir.dart';

void main() {
  const String dir = 'hsdd/contract/fixture/topology-ir';
  final List<String> names = <String>[
    for (final FileSystemEntity f in Directory('$dir/valid').listSync())
      if (f is File && f.path.endsWith('.json'))
        f.uri.pathSegments.last.replaceAll('.json', ''),
  ]..sort();
  var differing = 0;
  for (final String name in names) {
    final TopologyGraph graph = decodeTopologyGraph(
      jsonDecode(File('$dir/valid/$name.json').readAsStringSync()),
    );
    for (final (String ext, GraphRenderer renderer) in <(String, GraphRenderer)>[
      ('mmd', const MermaidRenderer()),
      ('dot', const GraphvizRenderer()),
    ]) {
      final List<String> rendered = graph.render(renderer).split('\n');
      final List<String> golden =
          File('$dir/render/$name.$ext').readAsStringSync().split('\n');
      final int at = <int>[
        for (int i = 0; i < rendered.length && i < golden.length; i++)
          if (rendered[i] != golden[i]) i,
        if (rendered.length != golden.length)
          rendered.length < golden.length ? rendered.length : golden.length,
      ].fold(-1, (int first, int i) => first < 0 || i < first ? i : first);
      if (at >= 0) {
        differing++;
        String line(List<String> lines) => at < lines.length ? lines[at] : '(none)';
        print('   render/$name.$ext differs first at line ${at + 1}: '
            'golden ${jsonEncode(line(golden))}, rendered ${jsonEncode(line(rendered))}');
      }
    }
  }
  print('   ${names.length} samples, $differing render/ files differ');
}
