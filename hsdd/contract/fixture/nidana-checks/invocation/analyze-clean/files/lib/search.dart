import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

import 'model.dart';
import 'topics.dart';

/// The bus is held by an instance and passed explicitly (Spec §3.1).
final class SearchService {
  SearchService(this.bus) : publisher = bus.publisher(const ServiceSource('search'));

  final Bus bus;
  final Publisher publisher;

  Bus get current => bus;

  void submit(String query) {
    bus.publish(SearchTopics.query, query);
    publisher.publish(SearchTopics.history, query);
  }

  Stream<int> counts() => bus.observe<int>(counterNamed('search.count'));

  SearchResults latest() => bus.getCurrentValue<SearchResults>(SearchTopics.results);
}

Bus createBus() {
  final Bus bus = Bus();
  return bus;
}

/// A topology writes and folds without type arguments.
final class SearchTopology extends Topology {
  const SearchTopology();

  @override
  String get topologyId => 'search';

  @override
  Scope get scope => Scope.application;

  @override
  void declare(TopologyBuilder b) {
    b.write(SearchTopics.results, b.read(SearchTopics.query).map(lookup));
    b.reduceInto(SearchTopics.clock, b.read(SearchTopics.query), tick);
  }
}

SearchResults lookup(String query) => SearchResults(<String>[query]);

int tick(int count, String query) => count + 1;
