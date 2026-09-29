
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/serial_queue.dart';

void main() {
  test('actions run one at a time, in submission order', () async {
    final queue = SerialQueue();
    final log = <String>[];

    Future<void> job(String name, int ms) => queue.run(() async {
      log.add('start $name');
      await Future<void>.delayed(Duration(milliseconds: ms));
      log.add('end $name');
    });

    // The first job is slowest; a parallel runner would finish it last.
    await Future.wait([job('a', 30), job('b', 5), job('c', 1)]);

    expect(log, [
      'start a', 'end a',
      'start b', 'end b',
      'start c', 'end c',
    ]);
  });

  test('a failing action fails only itself and does not block the next', () async {
    final queue = SerialQueue();

    final failing = queue.run<int>(() async => throw StateError('boom'));
    final after = queue.run<int>(() async => 42);

    await expectLater(failing, throwsA(isA<StateError>()));
    expect(await after, 42);
  });

  test('returns each action\'s own result', () async {
    final queue = SerialQueue();
    final results = await Future.wait([
      queue.run(() async => 'x'),
      queue.run(() async => 'y'),
    ]);
    expect(results, ['x', 'y']);
  });
}
