// Question (S153, topology-ir@v1 G9's derivation table): what does the
// derivation name for the function forms an extension or an extension type
// declares, under each compiler the tree can meet? The table says an
// "extension method tear-off" is anonymous; S135's review found that this
// holds for instance members only.
//
// The derivation is FunctionRef.of's (packages/nidana_dart_contracts,
// lib/src/ir/function_ref.dart), copied: the text between "from Function '"
// and the next "'", anonymous (null) when that text is absent or empty.

extension on int {
  int twice() => this * 2;
}

extension Ext on int {
  int triple() => this * 3;
  static int helper(int v) => v + 1;
  static int _helper(int v) => v + 2;
}

extension _Ext on int {
  static int helper(int v) => v + 3;
}

extension type _ET(int value) {}

extension type ET(int value) {
  ET.named(int v) : value = v * 10;
  factory ET.made(int v) => ET(v + 100);
  int plus(int v) => value + v;
  static int make(int v) => v - 1;
}

String? derive(Function f) {
  const String marker = "from Function '";
  final String rendering = f.toString();
  final int at = rendering.indexOf(marker);
  if (at < 0) return null;
  final int start = at + marker.length;
  final int end = rendering.indexOf("'", start);
  return end <= start ? null : rendering.substring(start, end);
}

void show(String label, Function f) {
  print('${label.padRight(44)}| ${f.toString().padRight(78)}| ${derive(f)}');
}

void main() {
  int Function() unnamedInstance = 4.twice;
  int Function() namedInstance = 4.triple;
  int Function() explicitInstance = Ext(5).triple;
  final ET et = ET(7);
  int Function(int) typeInstance = et.plus;
  show('unnamed extension, instance method', unnamedInstance);
  show('named extension, instance method', namedInstance);
  show('named extension, explicit instance method', explicitInstance);
  show('named extension, static method Ext.helper', Ext.helper);
  show('named extension, private static Ext._helper', Ext._helper);
  show('extension type, constructor ET.new', ET.new);
  show('extension type, named constructor ET.named', ET.named);
  show('extension type, factory ET.made', ET.made);
  show('extension type, instance method et.plus', typeInstance);
  show('extension type, static method ET.make', ET.make);
  show('private extension, static method _Ext.helper', _Ext.helper);
  show('private extension type, constructor _ET.new', _ET.new);
}
