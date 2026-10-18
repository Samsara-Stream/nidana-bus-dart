// Program b: a's libraries plus six more, imported before the probe library
// and used, so the program loads more libraries than a.
import 'package:probe/pad/p1.dart';
import 'package:probe/pad/p2.dart';
import 'package:probe/pad/p3.dart';
import 'package:probe/pad/p4.dart';
import 'package:probe/pad/p5.dart';
import 'package:probe/pad/p6.dart';
import 'package:probe/fns.dart';
import 'package:probe/report.dart';

void main() {
  print('b | padding sum ${p1() + p2() + p3() + p4() + p5() + p6()}');
  report('b', probeFunctions());
}
