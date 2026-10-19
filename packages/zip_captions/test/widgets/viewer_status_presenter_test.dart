import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/widgets/viewer_status_presenter.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/viewer_test_harness.dart';

const ZcStrings _strings = sentinelStrings;

ViewerStatusPresentation _present(ViewerSessionState state, {String? name}) =>
    presentViewerState(state, _strings, sessionName: name);

void main() {
  group('presentViewerState', () {
    test('every variant maps to a non-empty title', () {
      const states = <ViewerSessionState>[
        ViewerSessionState.idle(),
        ViewerSessionState.resolving(),
        ViewerSessionState.connecting(),
        ViewerSessionState.liveView(
          captionActivity: CaptionActivity.active,
          connectionType: ConnectionType.p2pDirect,
        ),
        ViewerSessionState.reconnecting(),
        ViewerSessionState.notBroadcasting(),
        ViewerSessionState.ended(),
        ViewerSessionState.full(),
        ViewerSessionState.cannotConnect(IceFailed()),
        ViewerSessionState.invalidInput(),
      ];

      for (final state in states) {
        expect(_present(state).title, isNotEmpty, reason: '$state');
      }
    });

    test('connecting names the session once it is known', () {
      expect(
        _present(const ViewerSessionState.connecting()).title,
        _strings.stateTitleConnecting,
      );
      expect(
        _present(
          const ViewerSessionState.connecting(),
          name: 'Ada',
        ).title,
        'viewerStateJoining',
      );
    });

    test('the named and nameless bodies are chosen by the name', () {
      expect(
        _present(const ViewerSessionState.ended()).body,
        _strings.endedBodyNameless,
      );
      expect(
        _present(const ViewerSessionState.ended(), name: 'Ada').body,
        'viewerEndedBodyNamed',
      );
      expect(
        _present(const ViewerSessionState.notBroadcasting()).body,
        _strings.notBroadcastingBodyNameless,
      );
      expect(
        _present(
          const ViewerSessionState.notBroadcasting(),
          name: 'Ada',
        ).body,
        'viewerNotBroadcastingBodyNamed',
      );
    });

    test('every ConnectFailure maps to distinct copy', () {
      const failures = <ConnectFailure>[
        NotFound(),
        RateLimited(),
        ResolutionFailed(),
        IceFailed(),
        Timeout(),
        SignalingRejected(),
        BroadcastFull(),
      ];
      final bodies = failures
          .map((f) => _present(ViewerSessionState.cannotConnect(f)).body)
          .toSet();

      expect(bodies, hasLength(failures.length));
      expect(bodies.every((b) => b != null && b.isNotEmpty), isTrue);
    });

    test('retry is offered only where it can help', () {
      bool retry(ConnectFailure failure) =>
          _present(ViewerSessionState.cannotConnect(failure)).canRetry;

      expect(retry(const NotFound()), isFalse);
      expect(retry(const RateLimited()), isFalse);
      expect(retry(const ResolutionFailed()), isTrue);
      expect(retry(const IceFailed()), isTrue);
      expect(retry(const Timeout()), isTrue);
      expect(retry(const SignalingRejected()), isTrue);
      expect(retry(const BroadcastFull()), isTrue);

      expect(_present(const ViewerSessionState.full()).canRetry, isTrue);
      expect(_present(const ViewerSessionState.ended()).canRetry, isFalse);
      expect(
        _present(const ViewerSessionState.invalidInput()).canRetry,
        isFalse,
      );
    });
  });

  group('isCaptionActivityPaused', () {
    test('the paused notice follows the broadcaster activity', () {
      for (final activity in CaptionActivity.values) {
        final state = ViewerSessionState.liveView(
          captionActivity: activity,
          connectionType: ConnectionType.turnRelayed,
        );
        expect(
          isCaptionActivityPaused(state),
          activity != CaptionActivity.active,
        );
      }
    });

    test('non-live states show no paused notice', () {
      const states = <ViewerSessionState>[
        ViewerSessionState.idle(),
        ViewerSessionState.resolving(),
        ViewerSessionState.connecting(),
        ViewerSessionState.reconnecting(),
        ViewerSessionState.notBroadcasting(),
        ViewerSessionState.ended(),
        ViewerSessionState.full(),
        ViewerSessionState.invalidInput(),
      ];
      for (final state in states) {
        expect(isCaptionActivityPaused(state), isFalse, reason: '$state');
      }
    });
  });
}
