Probes behind topic-codegen@v1's rules (hsdd/contract/topic-codegen.md), each
with its captured output:

- yaml_facts.dart -> yaml_facts.out.txt (P1): package:yaml 3.1.4 rejects a
  repeated mapping key and a second document, keeps mapping order, reads JSON,
  and types each scalar (an empty value is null, .inf a non-finite double,
  yes a string, a 20-digit integer a double). Run: fvm dart run probe/yaml_facts.dart
- doc/ -> doc/output.txt (P2): unintended_html_in_doc_comment reports a raw
  <int> in a doc comment and accepts a code span, a backslash escape, a
  spaced comparison and an autolink. Run: fvm dart analyze --format=machine probe/doc
- names/ -> names/output.txt (P3): a static member of an abstract final class
  fails to compile under exactly the 33 reserved words and hashCode,
  runtimeType, toString, noSuchMethod (FILE_NAMES infos come from the probe's
  own file names). Run: probe/names/run.sh > probe/names/output.txt
- flutter-vm/ (P5, run as T13 of ../run.sh): a library importing Flutter does
  not load under fvm dart run (dart:ui is not available) and loads under
  fvm flutter test.
