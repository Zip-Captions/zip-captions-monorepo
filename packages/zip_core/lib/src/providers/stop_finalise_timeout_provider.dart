import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/constants/stop_finalise_timeout.dart';

part 'stop_finalise_timeout_provider.g.dart';

/// The bound on Stop in force (BR-U10-58).
///
/// Returns [defaultStopFinaliseTimeout]. It follows
/// `speechInactivityTimeoutProvider`: the recording notifier reads it and
/// nothing else, and a test overrides it.
@Riverpod(keepAlive: true)
Duration stopFinaliseTimeout(Ref ref) => defaultStopFinaliseTimeout;
