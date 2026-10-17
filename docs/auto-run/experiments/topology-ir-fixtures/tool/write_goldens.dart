// Writes the sample graphs of the topology-ir@v1 conformance library, as the
// stand-in renders them, into {out}/valid/{sample}.json and
// {out}/render/{sample}.{mmd,dot}. Run from the experiment root, after
// run.sh's setup has copied the fixtures: write_goldens.dart {out}.
//
// These files become the contract's goldens only after a reading review: a
// golden written by the stand-in carries the stand-in's defects.
import 'dart:io';

import 'package:nidana_dart_contracts/topology_ir.dart';

import '../hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart';

void main(List<String> args) {
  final out = args.single;
  Directory('$out/valid').createSync(recursive: true);
  Directory('$out/render').createSync(recursive: true);
  for (final s in topologyIrSamples.entries) {
    final g = s.value();
    File('$out/valid/${s.key}.json').writeAsStringSync(g.render(const JsonRenderer()));
    File('$out/render/${s.key}.mmd').writeAsStringSync(g.render(const MermaidRenderer()));
    File('$out/render/${s.key}.dot').writeAsStringSync(g.render(const GraphvizRenderer()));
    print('wrote ${s.key}');
  }
}
