// The entry point `catalog` would generate at
// {package}/.dart_tool/nidana_dart_codegen/catalog_entry.dart. It imports the
// package's registration library by relative path (tool/ is not under lib/,
// so it has no package: URI), records every registered topology, and writes
// the graph document of their definitions.
//
// The output path comes from the OUT define: --dart-define=OUT=... under
// `flutter test`, -DOUT=... under `dart run`. main takes no parameters,
// because the Flutter tester's listener calls main().
import 'dart:io';

import 'package:nidana_dart_contracts/topology_ir.dart';

import '../../tool/nidana_catalog.dart' as registration;

void main() {
  const out = String.fromEnvironment('OUT');
  final definitions = [
    for (final t in registration.catalogTopologies()) t.buildDefinition(),
  ];
  File(out).writeAsStringSync(
    const JsonRenderer().render(TopologyGraph(topologies: definitions)),
  );
}
