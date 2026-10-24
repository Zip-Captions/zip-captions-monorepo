// Tests for Unit 8 (S-20): the external display state and event types.
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/output/overlay/caption_position.dart';
import 'package:zip_core/src/output/overlay/external_display_status.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/output/overlay/overlay_event.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';

String _statusName(ExternalDisplayStatus status) => switch (status) {
  Unsupported() => 'unsupported',
  NoDisplays() => 'noDisplays',
  Off() => 'off',
  Opening() => 'opening',
  Open() => 'open',
  WaitingForDisplay() => 'waiting',
  Failed() => 'failed',
};

String _eventName(OverlayEvent event) => switch (event) {
  DisplayLost() => 'displayLost',
  WindowClosed() => 'windowClosed',
  OpenFailed() => 'openFailed',
  // Deviation 2: the pop-out's in-surface toggle. Unit 8's controller never
  // emits it, but the sealed type is exhaustive from this test's point of
  // view, so the case is registered here once.
  PopOutToggled() => 'popOutToggled',
};

String _modeName(OverlayWindowMode mode) => switch (mode) {
  ExternalDisplayMode() => 'externalDisplay',
  PopOutMode() => 'popOut',
};

void main() {
  test('the seven status variants are exhaustively switchable', () {
    const statuses = <ExternalDisplayStatus>[
      Unsupported(),
      NoDisplays(),
      Off(),
      Opening(),
      Open(activity: OverlayActivity.live, displayId: 'display-1'),
      WaitingForDisplay(displayId: 'display-1'),
      Failed(reason: 'ready_timeout'),
    ];

    expect(statuses.map(_statusName), [
      'unsupported',
      'noDisplays',
      'off',
      'opening',
      'open',
      'waiting',
      'failed',
    ]);
  });

  test('the three event variants are exhaustively switchable', () {
    expect(
      [
        const DisplayLost(displayId: 'display-2'),
        const WindowClosed(),
        const OpenFailed('create_failed'),
      ].map(_eventName),
      ['displayLost', 'windowClosed', 'openFailed'],
    );
  });

  test('the mode hierarchy ships exactly one variant', () {
    expect(
      const ExternalDisplayMode(displayId: 'id'),
      isA<OverlayWindowMode>(),
    );
    expect(_modeName(const ExternalDisplayMode()), 'externalDisplay');
  });

  test('CaptionPosition and OverlayActivity encode by name', () {
    expect(CaptionPosition.values.map((v) => v.name), ['top', 'bottom']);
    expect(
      OverlayActivity.values.map((v) => v.name),
      ['standby', 'live', 'paused'],
    );
  });
}
