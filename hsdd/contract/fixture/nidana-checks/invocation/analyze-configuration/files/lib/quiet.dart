// Suppressed for the whole file.
// ignore_for_file: nidana_dart_lint/explicit_topic_type_arguments
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const EventTopic<int> quiet = EventTopic<int>(name: 'session.quiet');

void pingQuietly(Bus bus) => bus.publish<num, int>(quiet, 1);
