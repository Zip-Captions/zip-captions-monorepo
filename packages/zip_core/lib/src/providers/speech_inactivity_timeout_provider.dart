import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_core/src/constants/speech_inactivity.dart';

/// The inactivity timeout in force (BR-U10-52).
///
/// Returns [speechInactivityTimeout]. A future user setting overrides this
/// provider; the recording notifier and the notice read it and nothing else.
final speechInactivityTimeoutProvider = Provider<Duration>(
  (_) => speechInactivityTimeout,
);
