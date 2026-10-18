// Program c: b's libraries, the probe library imported before the six
// others, so c loads as many libraries as b in another directive order.
import 'package:probe/fns.dart';
import 'package:probe/pad/p1.dart';
import 'package:probe/pad/p2.dart';
import 'package:probe/pad/p3.dart';
import 'package:probe/pad/p4.dart';
import 'package:probe/pad/p5.dart';
import 'package:probe/pad/p6.dart';
import 'package:probe/report.dart';

void main() {
  print('c | padding sum ${p1() + p2() + p3() + p4() + p5() + p6()}');
  report('c', probeFunctions());
}
