// Checks the example document of the contract's Interface ("The JSON form"):
// it validates against the schema and the stand-in decodes it and
// re-encodes it to an equal JSON value. Run from the experiment root.
import 'dart:convert';
import 'dart:io';

import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

void main() {
  final doc = jsonDecode(File('interface-example.json').readAsStringSync());
  expectMatchesSchema(doc, 'hsdd/contract/schema/topology-ir.schema.json');
  final again = encodeTopologyGraph(decodeTopologyGraph(doc));
  if (jsonEncode(again) != jsonEncode(doc)) {
    print('FAIL re-encoded differently:\n${jsonEncode(again)}');
    exit(1);
  }
  print('PASS interface-example.json validates, decodes and re-encodes equal');
}
