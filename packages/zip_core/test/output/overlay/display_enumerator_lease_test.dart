// Tests for Unit 8.1 (S-21): the reference-counted display enumerator lease
// (NFR-D §3; NFR Design logical-components §3). N-03, the four lease cases.
//
// A controller is a long-lived holder of the engine's one enumerator, but its
// unchanged dispose() still disposes it. The lease makes that mean "release my
// share", so the moved `harness.enumerator.isDisposed` assertions keep their
// subject.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/output/overlay/display_enumerator.dart';
import 'package:zip_core/src/output/overlay/display_enumerator_lease.dart';

/// A minimal enumerator that records disposal. The moved `FakeDisplayEnumerator`
/// helper arrives with the controller suite in step 11; this test needs only
/// the disposal signal.
class _CountingEnumerator implements DisplayEnumerator {
  bool isDisposed = false;
  final List<String> calls = <String>[];

  @override
  Future<List<DisplayInfo>> displays() async => const <DisplayInfo>[];

  @override
  Stream<List<DisplayInfo>> get changes =>
      const Stream<List<DisplayInfo>>.empty();

  @override
  Future<Size?> primarySize() async => null;

  @override
  Future<void> dispose() async {
    if (isDisposed) return;
    isDisposed = true;
    calls.add('dispose');
  }
}

void main() {
  group('DisplayEnumeratorLease', () {
    test('an earlier release does not dispose the shared instance', () async {
      final shared = _CountingEnumerator();
      final host = DisplayEnumeratorHost(shared);
      final a = host.lease();
      final b = host.lease();

      await a.dispose();

      expect(a.isReleased, isTrue);
      expect(shared.isDisposed, isFalse);
      expect(host.outstanding, 1);

      await b.dispose();
    });

    test('the last release disposes the shared instance', () async {
      final shared = _CountingEnumerator();
      final host = DisplayEnumeratorHost(shared);
      final a = host.lease();
      final b = host.lease();

      await a.dispose();
      await b.dispose();

      expect(shared.isDisposed, isTrue);
      expect(host.outstanding, 0);
    });

    test('a double release is a no-op', () async {
      final shared = _CountingEnumerator();
      final host = DisplayEnumeratorHost(shared);
      final a = host.lease();
      host.lease();

      await a.dispose();
      await a.dispose();

      expect(shared.isDisposed, isFalse);
      expect(host.outstanding, 1);
    });

    test('host.dispose disposes regardless, and a later release is a no-op',
        () async {
      final shared = _CountingEnumerator();
      final host = DisplayEnumeratorHost(shared);
      final a = host.lease();
      host.lease();

      await host.dispose();
      expect(shared.isDisposed, isTrue);

      final disposeCount = shared.calls.where((c) => c == 'dispose').length;
      await a.dispose();
      await host.dispose();

      expect(
        shared.calls.where((c) => c == 'dispose').length,
        disposeCount,
        reason: 'the shared instance is disposed exactly once',
      );
      expect(host.outstanding, 0);
    });

    test('a lease delegates every member to the shared instance', () async {
      final shared = _CountingEnumerator();
      final host = DisplayEnumeratorHost(shared);
      final lease = host.lease();

      expect(await lease.displays(), await shared.displays());
      expect(await lease.primarySize(), isNull);
      expect(identical(lease.shared, shared), isTrue);
      expect(lease.changes, isNotNull);

      await lease.dispose();
    });
  });
}