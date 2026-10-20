// Three ways bus.observe's stream can run a subscriber's callbacks, over a
// source that lives in the provider zone. In all three, `listen` subscribes
// inside the provider zone, so the source's first-value microtask and every
// delivery are provider-zone work (ADR-003 item 2 as accepted).
//
//   today    the subscriber's callbacks run in the provider zone; an exception
//            goes to the provider zone's uncaught-error handler (ADR-003 as
//            accepted, bus-api@v1 G18).
//   forward  the callbacks still run in the provider zone; each exception a
//            callback throws, and an error event the subscriber leaves
//            unhandled, is forwarded to the uncaught-error handler of the zone
//            in which `listen` was called (option A).
//   bind     the callbacks run in the zone in which `listen` was called
//            (registered there, invoked with runUnaryGuarded), as on any Dart
//            stream; exceptions go to that zone's handler (option B).
//
// Throwaway experiment code; not the runtime's implementation.
import 'dart:async';

enum Strategy { today, forward, bind }

final class Observed<T> extends Stream<T> {
  Observed(this._source, this._provider, this.strategy);
  final Stream<T> _source;
  final Zone _provider;
  final Strategy strategy;

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final listenZone = Zone.current;
    switch (strategy) {
      case Strategy.today:
        return _provider.run(() => _source.listen(onData,
            onError: onError, onDone: onDone, cancelOnError: cancelOnError));
      case Strategy.forward:
        final inner = _provider.run(() => _source.listen(null,
            cancelOnError: cancelOnError));
        return _ForwardingSubscription<T>(inner, listenZone)
          ..onData(onData)
          ..onError(onError)
          ..onDone(onDone);
      case Strategy.bind:
        final inner = _provider.run(() => _source.listen(null,
            cancelOnError: cancelOnError));
        return _BoundSubscription<T>(inner, listenZone)
          ..onData(onData)
          ..onError(onError)
          ..onDone(onDone);
    }
  }
}

void _callUnary(Function handler, Object e, StackTrace st) {
  if (handler is void Function(Object, StackTrace)) {
    handler(e, st);
  } else {
    (handler as void Function(Object))(e);
  }
}

/// Option A. Handlers set at listen or later run in the provider zone, inside
/// a try/catch that sends what they throw to the listen zone's handler.
final class _ForwardingSubscription<T> implements StreamSubscription<T> {
  _ForwardingSubscription(this._inner, this._listenZone);
  final StreamSubscription<T> _inner;
  final Zone _listenZone;

  void _guard(void Function() f) {
    try {
      f();
    } catch (e, st) {
      _listenZone.handleUncaughtError(e, st);
    }
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(
      handleData == null ? null : (v) => _guard(() => handleData(v)));

  @override
  void onError(Function? handleError) => _inner.onError(handleError == null
      // Unhandled error event: what Dart does, but in the listen zone.
      ? (Object e, StackTrace st) => _listenZone.handleUncaughtError(e, st)
      : (Object e, StackTrace st) => _guard(() => _callUnary(handleError, e, st)));

  @override
  void onDone(void Function()? handleDone) =>
      _inner.onDone(handleDone == null ? null : () => _guard(handleDone));

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  bool get isPaused => _inner.isPaused;
  @override
  Future<void> cancel() => _inner.cancel();
  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}

/// Option B. Handlers are registered in the listen zone and invoked there.
final class _BoundSubscription<T> implements StreamSubscription<T> {
  _BoundSubscription(this._inner, this._listenZone);
  final StreamSubscription<T> _inner;
  final Zone _listenZone;

  @override
  void onData(void Function(T data)? handleData) {
    if (handleData == null) return _inner.onData(null);
    final h = _listenZone.registerUnaryCallback<void, T>(handleData);
    _inner.onData((v) => _listenZone.runUnaryGuarded(h, v));
  }

  @override
  void onError(Function? handleError) {
    if (handleError == null) {
      return _inner.onError(
          (Object e, StackTrace st) => _listenZone.handleUncaughtError(e, st));
    }
    _inner.onError((Object e, StackTrace st) =>
        _listenZone.runGuarded(() => _callUnary(handleError, e, st)));
  }

  @override
  void onDone(void Function()? handleDone) {
    if (handleDone == null) return _inner.onDone(null);
    final h = _listenZone.registerCallback<void>(handleDone);
    _inner.onDone(() => _listenZone.runGuarded(h));
  }

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  bool get isPaused => _inner.isPaused;
  @override
  Future<void> cancel() => _inner.cancel();
  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}
