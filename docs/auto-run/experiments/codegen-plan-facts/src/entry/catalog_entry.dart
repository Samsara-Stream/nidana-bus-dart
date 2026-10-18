// The entry point catalog generates at
// {package}/.dart_tool/nidana_dart_codegen/catalog_entry.dart (stand-in: it
// writes the topology ids, not a graph document).
import 'dart:io';

import '../../tool/nidana_catalog.dart' as registration;

void main() {
  const out = String.fromEnvironment('OUT');
  File(out).writeAsStringSync(
    '${[for (final t in registration.catalogTopologies()) t.topologyId].join(',')}\n',
  );
}
