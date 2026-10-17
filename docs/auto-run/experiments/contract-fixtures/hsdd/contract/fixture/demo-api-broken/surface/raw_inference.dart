import 'package:demo_contracts/demo_contracts.dart';

// A raw generic use that only strict analysis modes flag.
List makeList() => [const EventTopic<int>('a.b')];
final topics = [];
