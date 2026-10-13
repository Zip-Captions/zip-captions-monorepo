import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/transport_selector.dart';

part 'broadcast_transport_factory_provider.g.dart';

/// Provides a factory for the app's [BroadcastTransport].
///
/// Not `transportSelectorProvider` returning [TransportSelector] directly:
/// `TransportSelector.broadcastTransport()`'s declared return type is the
/// concrete `WebRtcBroadcastTransport` (fixed shape, Application Design,
/// Unit 5), not the [BroadcastTransport] interface — overriding a provider
/// typed to that concrete class could never substitute a fake in
/// `BroadcastSessionNotifier`'s own tests (NFR Requirements Q1). This
/// provider's declared return type is the interface; the real factory
/// closure still just calls `TransportSelector().broadcastTransport()` —
/// a `WebRtcBroadcastTransport` is a `BroadcastTransport`, so no cast is
/// needed, only a wider declared type.
@Riverpod(keepAlive: true)
BroadcastTransport Function() broadcastTransportFactory(Ref ref) =>
    () => const TransportSelector().broadcastTransport();
