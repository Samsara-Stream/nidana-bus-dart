// P1: does the static type's display string equal the TopicRef.typeName the
// VM renders ('$T') for the same declaration? The scan builds claims' and
// declarations' TopicRefs statically; the graph document's come from the VM.
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;

import '../probe/type_names/lib/topics.dart' as probe;

Future<void> main() async {
  final String file = p.normalize(p.absolute('probe/type_names/lib/topics.dart'));
  final AnalysisContextCollection c = AnalysisContextCollection(includedPaths: <String>[file]);
  final Object unit = await c.contextFor(file).currentSession.getResolvedUnit(file);
  final Map<String, String> static = <String, String>{};
  for (final AstNode d in (unit as ResolvedUnitResult).unit.declarations) {
    if (d is! ClassDeclaration) continue;
    for (final ClassMember m in (d.body as BlockClassBody).members) {
      if (m is! FieldDeclaration) continue;
      for (final VariableDeclaration v in m.fields.variables) {
        final InterfaceType t = v.declaredFragment!.element.type as InterfaceType;
        static[v.name.lexeme] = t.typeArguments.first.getDisplayString();
      }
    }
  }
  final List<String> names = static.keys.toList();
  for (int i = 0; i < probe.all.length; i++) {
    final String vm = probe.all[i].ref.typeName;
    final String st = static[names[i]]!;
    stdout.writeln('${names[i].padRight(12)} vm: ${vm.padRight(22)} static: ${st.padRight(22)} ${vm == st ? 'EQUAL' : 'DIFFERENT'}');
  }
}
