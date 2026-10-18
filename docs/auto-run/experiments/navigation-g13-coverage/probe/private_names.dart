// T7: what FunctionRef.of (topology-ir@v1 G9) yields for a private top-level
// function, as the fixture's _principalOf is, and for a public method of a
// private class, as the named stand-in's stage functions are. Seen in T4b: the
// VM renders a private name with a library key, `_principalOf@{key}`.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

int _privateTopLevel(int x) => x;
int publicTopLevel(int x) => x;

final class _Stage {
  const _Stage();
  int resolveDeepLinks(int x) => x;
  int _privateMethod(int x) => x;
}

void main() {
  const _Stage s = _Stage();
  print('private top-level: ${FunctionRef.of(_privateTopLevel)}');
  print('public top-level: ${FunctionRef.of(publicTopLevel)}');
  print('public method of a private class: ${FunctionRef.of(s.resolveDeepLinks)}');
  print('private method: ${FunctionRef.of(s._privateMethod)}');
}
