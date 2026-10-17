import 'package:clock/clock.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wl_contracts/wl_contracts.dart';

export 'src/internal.dart' show Bus;

BehaviorSubject<TopicName> seeded() =>
    BehaviorSubject<TopicName>.seeded(const TopicName('a.b'), sync: true);

DateTime stamp() => clock.now();
