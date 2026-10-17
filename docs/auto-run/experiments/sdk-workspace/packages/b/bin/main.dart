import 'package:exp_a/exp_a.dart';

void main() {
  final s = seeded();
  s.listen((v) => print('b sees $v'));
  s.add(1);
  print('workspace member b resolved exp_a and rxdart through the workspace root');
}
