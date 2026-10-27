// What the analyzer reports once the topic-model values override `==` (S124,
// step A of run.sh). run.sh copies this file into the package's test/
// directory of a temporary workspace, analyzes it against the committed
// declarations (Object's `==`) and against the drafted ones, and removes it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

const TopicRef ref = TopicRef(
  name: 'a.b',
  variant: TopicVariant.state,
  typeName: 'int',
);
const StateTopic<int> count = StateTopic<int>(name: 'a.count', initial: 0);

// A1 a non-empty const set of refs.
const Set<TopicRef> refs = <TopicRef>{ref};

// A2 a non-empty const set of topics.
const Set<StateTopic<int>> topics = <StateTopic<int>>{count};

// A3 a const map keyed by sources.
const Map<MessageSource, int> bySource = <MessageSource, int>{
  ServiceSource('s'): 1,
};

// A4 a const map whose values are refs.
const Map<String, TopicRef> byName = <String, TopicRef>{'a.b': ref};

// A5 a const list of refs, an empty const set of refs, a const set of enums.
const List<TopicRef> list = <TopicRef>[ref];
const Set<TopicRef> none = <TopicRef>{};
const Set<Scope> scopes = <Scope>{Scope.page, Scope.module};

// A6 a constant pattern of a type that overrides `==`.
String label(TopicRef r) => switch (r) {
  ref => 'a.b',
  _ => 'other',
};

// A7 a set literal that is not const.
final Set<TopicRef> runtime = <TopicRef>{ref};

// A8 a const set nested in a const list (an implicit const context).
const List<Set<TopicRef>> nested = <Set<TopicRef>>[
  <TopicRef>{ref},
];
