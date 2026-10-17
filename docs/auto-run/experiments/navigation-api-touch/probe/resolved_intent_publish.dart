// Q: what a publish to nav.resolved-intent accepts under bus-api@v1 G40's
// signature, publish<T extends Object?, V extends T>(MultiWriterTopic<T>
// topic, V value), on the stand-in runtime, and what it accepted under the
// signature navigation-api@v1 was first written against,
// publish<T>(MultiWriterTopic<T> topic, T value). Each line is tagged; run.sh
// prints the (line, code) pairs, and a tagged line with no pair compiles.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

// The pre-amendment form, declared locally (bus-api@v1 before S13).
void oldPublish<T>(MultiWriterTopic<T> topic, T value) {}

const NavRoute<void> home = NavRoute<void>('app/home');

void probe(Bus bus, Publisher pages, Uri uri, NavIntent anyIntent) {
  pages.publish(NavigationTopics.resolvedIntent, DeepLink(uri)); // Q01 the new G1 line, publisher
  bus.publish(NavigationTopics.resolvedIntent, DeepLink(uri)); // Q02 the new G1 line, publisher-less
  pages.publish(NavigationTopics.resolvedIntent, anyIntent); // Q03 a value typed NavIntent
  pages.publish(NavigationTopics.resolvedIntent, const Back()); // Q04 a resolved intent compiles
  pages.publish(NavigationTopics.resolvedIntent, home.go()); // Q05 a route-built intent compiles
  pages.publish(NavigationTopics.intent, DeepLink(uri)); // Q06 a deep link on nav.intent compiles
  bus.publish(NavigationTopics.intent, home.go()); // Q07 a resolved intent on nav.intent compiles
  pages.publish<NavIntent, DeepLink>(NavigationTopics.resolvedIntent, DeepLink(uri)); // Q08 explicit type arguments widen T, outside G40
  oldPublish(NavigationTopics.resolvedIntent, DeepLink(uri)); // Q09 the pre-amendment form compiles
}
