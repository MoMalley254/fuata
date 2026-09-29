import 'dart:async';

/// Runs async actions strictly one after another, in the order they were
/// submitted. A failing action completes *its own* future with the error
/// and never blocks the actions behind it.
///
/// Why this exists (issue #22): capture is check-then-insert (dedupe reads
/// the stored rows, then writes one). Two notifications arriving together
/// — say the same payment as an SMS and as a push — would both read
/// "nothing stored yet" and both insert. Serialising the whole
/// check-and-insert closes that race inside one isolate.
class SerialQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}