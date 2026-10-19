import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/webrtc/transport_selector.dart';
import 'package:zip_core/src/services/webrtc/viewer_transport.dart';

part 'viewer_transport_factory_provider.g.dart';

/// Provides a factory for the app's [ViewerTransport] (mirrors
/// `broadcast_transport_factory_provider.dart`).
///
/// Not `TransportSelector` directly: `TransportSelector.viewerTransport()`'s
/// declared return type is the concrete `WebRtcViewerTransport` (fixed
/// shape, Application Design), which a test fake could never substitute.
/// This provider's declared return type is the interface; the real factory
/// closure still just calls `TransportSelector().viewerTransport()` — the
/// concrete class is a [ViewerTransport], so no cast is needed, only a wider
/// declared type. Overridden in tests with a fake (NFR Requirements Q1).
@Riverpod(keepAlive: true)
ViewerTransport Function() viewerTransportFactory(Ref ref) =>
    () => const TransportSelector().viewerTransport();