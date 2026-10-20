// The decisive cases of bin/main.dart inside real package:test bodies. The
// virtual scheduler (the TestBus stand-in) is built in setUpAll, so the zone a
// test body listens from is not the zone the scheduler was constructed in.
//
// Expected by design: under `today` and `bind`, some tests fail; the run
// records which, and where the error was reported.
import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:subscriber_error_zone/observe.dart';
import 'package:subscriber_error_zone/scheduler.dart';
import 'package:test/test.dart';

void main() {
  for (final s in Strategy.values) {
    group(s.name, () {
      late VirtualScheduler vs;
      setUpAll(() => vs = VirtualScheduler());

      (BehaviorSubject<int>, Observed<int>) topic() {
        final subject =
            vs.zone.run(() => BehaviorSubject<int>.seeded(0, sync: true));
        return (subject, Observed<int>(subject.stream, vs.zone, s));
      }

      test('T1 first and live values arrive through scheduler operations, '
          'without await', () {
        final (subject, observed) = topic();
        final got = <int>[];
        observed.listen(got.add);
        expect(got, isEmpty);
        vs.triggerActions();
        expect(got, [0]);
        subject.add(1);
        expect(got, [0, 1]);
      });

      test('T2 a throwing subscriber fails the test that listened', () {
        final (subject, observed) = topic();
        final other = <int>[];
        observed.listen((v) {
          if (v == 1) throw StateError('T2 subscriber threw ($s)');
        });
        observed.listen(other.add);
        vs.triggerActions();
        subject.add(1);
        subject.add(2);
        expect(other, [0, 1, 2]);
      });

      test('T3 debounceTime chained onto the observed stream follows '
          'virtual time', () {
        final (subject, observed) = topic();
        final got = <int>[];
        observed.debounceTime(const Duration(milliseconds: 300)).listen(got.add);
        vs.triggerActions();
        subject.add(7);
        vs.advanceTimeBy(const Duration(milliseconds: 300));
        expect(got, [7]);
      });

      test('T4 a Timer a subscriber callback creates follows virtual time', () {
        final (subject, observed) = topic();
        var fired = false;
        observed.listen((v) {
          if (v == 5) {
            Timer(const Duration(milliseconds: 100), () => fired = true);
          }
        });
        vs.triggerActions();
        subject.add(5);
        vs.advanceTimeBy(const Duration(milliseconds: 100));
        expect(fired, isTrue);
      });

      test('T5 next test after T2..T4, passes trivially', () {});
    });
  }
}
