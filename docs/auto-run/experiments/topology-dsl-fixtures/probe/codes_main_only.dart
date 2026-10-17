// Probe: the plan declarations are not reachable from the main library.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

MapStage<int, int>? stage; // Q1
TopologyPlan? plan; // Q2
Object? p(Topology t) => planOf(t); // Q3
Object? v(TopicStream<int> s) => visitStage(s, throw 0); // Q4
