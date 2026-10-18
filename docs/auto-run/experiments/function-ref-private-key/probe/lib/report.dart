// Prints, per probe function: its toString() and the name topology-ir@v1 G9's
// rule derives (the text between "from Function '" and the next "'",
// anonymous when absent or empty).

final RegExp _vmName = RegExp(r"from Function '([^']*)'");

String derive(Function f) {
  final String? found = _vmName.firstMatch(f.toString())?.group(1);
  return found == null || found.isEmpty ? '(anonymous)' : found;
}

void report(String program, Map<String, Function> functions) {
  for (final MapEntry<String, Function> e in functions.entries) {
    print('$program | ${e.key.padRight(38)} | ${derive(e.value).padRight(30)} | ${e.value}');
  }
}
