import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/constants/speech_inactivity.dart';

part 'speech_inactivity_timeout_provider.g.dart';

/// The inactivity timeout in force (BR-U10-52).
///
/// Returns [defaultSpeechInactivityTimeout]. A future user setting overrides
/// this provider; the recording notifier and the notice read it and nothing
/// else.
@Riverpod(keepAlive: true)
Duration speechInactivityTimeout(Ref ref) => defaultSpeechInactivityTimeout;
