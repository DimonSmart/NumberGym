import 'dart:async';

/// Executes commands in submission order without allowing a failed command to
/// poison commands submitted afterwards.
final class SerializedOperationQueue {
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  Future<T> enqueue<T>(Future<T> Function() operation) {
    if (_closed) {
      return Future<T>.error(StateError('Operation queue is closed.'));
    }
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> close() {
    _closed = true;
    return _tail;
  }
}
