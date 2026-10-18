// B10: resolves every library of the package root given as the first
// argument with the analyzer, and prints, per class a library declares, the
// URI of the library declaring its superclass: what recognition by package
// and element name reads (nidana-checks@v1 Recognition).
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

Future<void> main(List<String> args) async {
  final root = Directory(args.single).absolute.path;
  final collection = AnalysisContextCollection(includedPaths: [root]);
  for (final context in collection.contexts) {
    final files = context.contextRoot.analyzedFiles().where((f) => f.endsWith('.dart')).toList()..sort();
    for (final file in files) {
      final result = await context.currentSession.getResolvedLibrary(file);
      if (result is! ResolvedLibraryResult) {
        stdout.writeln('${file.substring(root.length)}: not resolved ($result)');
        continue;
      }
      final errors = [
        for (final unit in result.units)
          for (final d in unit.diagnostics) d.diagnosticCode.lowerCaseName,
      ];
      for (final c in result.element.classes) {
        stdout.writeln('${file.substring(root.length)}: ${c.name} extends ${c.supertype?.element.name} '
            'from ${c.supertype?.element.library.uri}; diagnostics: ${errors.isEmpty ? 'none' : errors.join(', ')}');
      }
    }
  }
}
