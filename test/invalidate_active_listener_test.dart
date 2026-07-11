import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

int constructCount = 0;

class FakeNotifier extends StateNotifier<int> {
  FakeNotifier() : super(0) {
    constructCount++;
  }
}

final fakeProvider = StateNotifierProvider<FakeNotifier, int>((ref) => FakeNotifier());

void main() {
  test('invalidate() with NO active listener defers reconstruction until next explicit read', () async {
    constructCount = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(fakeProvider); // construct #1, no listener kept
    expect(constructCount, 1);

    container.invalidate(fakeProvider);
    await Future<void>.delayed(Duration.zero); // flush microtasks

    // Still 1: nobody is listening, so nothing forced a rebuild yet.
    expect(constructCount, 1, reason: 'no active listener — should stay lazy');

    container.read(fakeProvider); // the "next explicit read"
    expect(constructCount, 2);
  });

  test('invalidate() WITH an active listener rebuilds immediately, before any explicit re-read', () async {
    constructCount = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Simulates a still-mounted widget (e.g. DashboardScreen underneath a
    // pushed ProfileScreen) actively watching this provider via ref.watch.
    final sub = container.listen(fakeProvider, (prev, next) {});
    addTearDown(sub.close);
    expect(constructCount, 1);

    container.invalidate(fakeProvider);
    await Future<void>.delayed(Duration.zero); // flush microtasks — no explicit read anywhere

    expect(constructCount, 2,
        reason: 'an active listener forces Riverpod to eagerly rebuild so the '
            'listener keeps receiving values — this is NOT lazy the way a '
            'provider with zero listeners is');
  });
}
