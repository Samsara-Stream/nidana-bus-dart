// Program both: the probe library and its copy at another URL, in one process.
import 'package:probe/fns.dart' as here;
import 'package:probe/moved/fns.dart' as moved;
import 'package:probe/report.dart';

void main() {
  report('both/fns', here.probeFunctions());
  report('both/moved', moved.probeFunctions());
}
