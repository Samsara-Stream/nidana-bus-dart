// Candidate declaration forms for topology-dsl@v1's write path and handle
// typing. Question: which form makes "a handle of the wrong value type written
// to a topic" a compile error (Spec §4.2), given that Dart class generics are
// covariant and that inference solves a type argument constrained by two
// arguments to their least upper bound?
//
// Throwaway experiment code.
library;

// A covariant topic family, as topic-model@v1 declares it.
sealed class Topic<T> {
  const Topic(this.name);
  final String name;
}

final class StateTopic<T> extends Topic<T> {
  const StateTopic(super.name, this.initial);
  final T initial;
}

final class EventTopic<T> extends Topic<T> {
  const EventTopic(super.name);
}

// ------------------------------------------------------------ handles

/// A plain covariant handle.
final class Handle<T> {
  Handle._();
  factory Handle.make() => Handle<T>._();

  Handle<R> map<R>(R Function(T value) transform) => Handle<R>._();

  /// Form 3: the handle writes itself to a topic.
  void writeTo(Topic<T> topic) {}
}

// ------------------------------------------------------------ builders

final class Builder {
  /// Form 1: one type parameter shared by both arguments.
  void write<T>(Topic<T> topic, Handle<T> stream) {}

  /// Form 2: the stream's type bounded by the topic's.
  void write2<T, S extends T>(Topic<T> topic, Handle<S> stream) {}

  /// Form 4: curried; the topic fixes T, the stream is checked against it.
  WriteTarget<T> writeCurried<T>(Topic<T> topic) => WriteTarget<T>._();

  /// Form 6: horizontal inference through a function literal.
  void writeLazy<T>(Topic<T> topic, Handle<T> Function() stream) {}

  /// reduceInto: the reducer's type is invariant in S.
  void reduceInto<S, E>(
    StateTopic<S> topic,
    Handle<E> events,
    S Function(S state, E event) reducer,
  ) {}

  Handle<R> combine2<A, B, R>(
    Handle<A> a,
    Handle<B> b,
    R Function(A a, B b) combiner,
  ) =>
      Handle<R>._();
}

final class WriteTarget<T> {
  WriteTarget._();
  void from(Handle<T> stream) {}
}

/// Form 9: an extension on the topic; its type argument is inferred from the
/// receiver alone.
extension TopicWrites<T> on Topic<T> {
  void writeFrom(Builder b, Handle<T> stream) {}
}

// ------------------------------------------------------------ form 5

/// Invariance encoded through a function type: InvHandle<T> is
/// _InvHandle<T, T Function(T)>, and T Function(T) is invariant in T.
typedef InvHandle<T> = Inv<T, T Function(T)>;

final class Inv<T, F> {
  Inv._();
  static InvHandle<T> make<T>() => Inv<T, T Function(T)>._();
}

final class InvBuilder {
  void write<T>(Topic<T> topic, InvHandle<T> stream) {}
}
