// PBT generator library for zip_broadcast glados tests.
//
// Centralized Arbitrary<T> instances for zip_broadcast domain types.

import 'package:glados/glados.dart';
import 'package:zip_broadcast/src/models/obs_connection_state.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';

/// Generates all sealed [ObsConnectionState] variants with plausible fields.
final Generator<ObsConnectionState> arbitraryObsConnectionState =
    any.choose(<ObsConnectionState>[
  const ObsDisconnected(),
  const ObsConnecting(),
  const ObsConnected(),
  const ObsReconnecting(attempt: 1, nextRetryMs: 1000),
  const ObsReconnecting(attempt: 3, nextRetryMs: 4000),
  const ObsReconnecting(attempt: 6, nextRetryMs: 30000),
  const ObsError(message: 'connection failed'),
  const ObsError(message: 'Could not connect to OBS after 10 minutes.'),
]);

/// Generates [OutputTargetSettings] with random bool toggles and a valid port.
final Generator<OutputTargetSettings> arbitraryOutputTargetSettings =
    any.combine5(
  any.bool,
  any.bool,
  any.bool,
  any.bool,
  any.intInRange(1024, 65536),
  (onScreen, obs, browser, overlay, port) => OutputTargetSettings(
    onScreenEnabled: onScreen,
    obsEnabled: obs,
    browserSourceEnabled: browser,
    overlayEnabled: overlay,
    browserSourcePort: port,
  ),
);
