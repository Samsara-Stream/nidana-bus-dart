// Does fake_async 1.3.3's elapse return when a zero-period periodic timer is
// pending? Run under a 10 s watchdog (see output-fake-async.txt).
import 'dart:async';
import 'package:fake_async/fake_async.dart';

void main() {
  var fires = 0;
  fakeAsync((fa) {
    Timer.periodic(Duration.zero, (_) {
      if (++fires % 1000000 == 0) print('fires so far: $fires');
    });
    fa.elapse(const Duration(milliseconds: 1));
    print('elapse returned after $fires fires');
  });
}
