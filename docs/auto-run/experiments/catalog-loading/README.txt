catalog-loading: runtime facts behind OQ-T1's residual (hsdd/spec/nidana.tooling.md),
decided in hsdd/spec/nidana.tooling.codegen.md.

Question: topic-codegen@v1's `catalog` must call buildDefinition() of every
topology a package registers, on the Dart VM in JIT mode (G20). Given a
registration library an app writes at `tool/nidana_catalog.dart`, and an
entry point that `catalog` would generate under the package's
`.dart_tool/nidana_dart_codegen/`, which runner loads which package, and do
the two runners record the same definitions?

Layout (run.sh copies src/ into work/, adds the stand-in nidana_dart_contracts
of ../flutter-binding-fixtures/, and removes work/ when it ends):

- src/pubspec.yaml: a pub workspace with three members.
- src/packages/domain: pure Dart; a class topology with a zero-argument
  constructor and a parameterized topology factory whose transformer is a
  top-level function passed as an argument (build-time configuration).
- src/packages/app: a Flutter package (flutter_test as a dev dependency) whose
  page library imports package:flutter/widgets.dart and declares a page
  topology next to a widget; its registration lists that topology and the
  domain's topologies.
- src/packages/app_bare: a Flutter package without flutter_test.
- src/entry/catalog_entry.dart: the entry point catalog would generate: it
  imports the registration library by relative path, records every topology,
  and writes JsonRenderer output to the path the OUT define names
  (--dart-define under flutter test, -D under dart run).

Run: ./run.sh > output.txt 2>&1
