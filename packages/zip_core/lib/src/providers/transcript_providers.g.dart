// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptRepositoryHash() =>
    r'19c2053913c1d645c9bfa19c4bf2451ce6538e6c';

/// Provides a file-backed [TranscriptRepository] for the session lifetime.
///
/// Opens `transcripts.db` in the application documents directory.
/// Corruption is handled by [TranscriptDatabase.open]; the repository
/// emits a `RepositoryEvent.corruption` event when recovery occurs.
///
/// Copied from [transcriptRepository].
@ProviderFor(transcriptRepository)
final transcriptRepositoryProvider =
    FutureProvider<TranscriptRepository>.internal(
      transcriptRepository,
      name: r'transcriptRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TranscriptRepositoryRef = FutureProviderRef<TranscriptRepository>;
String _$transcriptSessionListHash() =>
    r'ac5f2f61db5b00dbacab248a653275b8317f4167';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Returns all sessions ordered by date descending, or BM25-ranked search
/// results when [query] is non-empty.
///
/// Copied from [transcriptSessionList].
@ProviderFor(transcriptSessionList)
const transcriptSessionListProvider = TranscriptSessionListFamily();

/// Returns all sessions ordered by date descending, or BM25-ranked search
/// results when [query] is non-empty.
///
/// Copied from [transcriptSessionList].
class TranscriptSessionListFamily
    extends Family<AsyncValue<List<TranscriptSession>>> {
  /// Returns all sessions ordered by date descending, or BM25-ranked search
  /// results when [query] is non-empty.
  ///
  /// Copied from [transcriptSessionList].
  const TranscriptSessionListFamily();

  /// Returns all sessions ordered by date descending, or BM25-ranked search
  /// results when [query] is non-empty.
  ///
  /// Copied from [transcriptSessionList].
  TranscriptSessionListProvider call(String query) {
    return TranscriptSessionListProvider(query);
  }

  @override
  TranscriptSessionListProvider getProviderOverride(
    covariant TranscriptSessionListProvider provider,
  ) {
    return call(provider.query);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'transcriptSessionListProvider';
}

/// Returns all sessions ordered by date descending, or BM25-ranked search
/// results when [query] is non-empty.
///
/// Copied from [transcriptSessionList].
class TranscriptSessionListProvider
    extends AutoDisposeFutureProvider<List<TranscriptSession>> {
  /// Returns all sessions ordered by date descending, or BM25-ranked search
  /// results when [query] is non-empty.
  ///
  /// Copied from [transcriptSessionList].
  TranscriptSessionListProvider(String query)
    : this._internal(
        (ref) => transcriptSessionList(ref as TranscriptSessionListRef, query),
        from: transcriptSessionListProvider,
        name: r'transcriptSessionListProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$transcriptSessionListHash,
        dependencies: TranscriptSessionListFamily._dependencies,
        allTransitiveDependencies:
            TranscriptSessionListFamily._allTransitiveDependencies,
        query: query,
      );

  TranscriptSessionListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<List<TranscriptSession>> Function(
      TranscriptSessionListRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TranscriptSessionListProvider._internal(
        (ref) => create(ref as TranscriptSessionListRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TranscriptSession>> createElement() {
    return _TranscriptSessionListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptSessionListProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TranscriptSessionListRef
    on AutoDisposeFutureProviderRef<List<TranscriptSession>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _TranscriptSessionListProviderElement
    extends AutoDisposeFutureProviderElement<List<TranscriptSession>>
    with TranscriptSessionListRef {
  _TranscriptSessionListProviderElement(super.provider);

  @override
  String get query => (origin as TranscriptSessionListProvider).query;
}

String _$transcriptSessionHash() => r'f216cc4e77670fe6744f47d5adf53d87afb28461';

/// Returns the session with [sessionId], or `null` if it does not exist.
///
/// Copied from [transcriptSession].
@ProviderFor(transcriptSession)
const transcriptSessionProvider = TranscriptSessionFamily();

/// Returns the session with [sessionId], or `null` if it does not exist.
///
/// Copied from [transcriptSession].
class TranscriptSessionFamily extends Family<AsyncValue<TranscriptSession?>> {
  /// Returns the session with [sessionId], or `null` if it does not exist.
  ///
  /// Copied from [transcriptSession].
  const TranscriptSessionFamily();

  /// Returns the session with [sessionId], or `null` if it does not exist.
  ///
  /// Copied from [transcriptSession].
  TranscriptSessionProvider call(String sessionId) {
    return TranscriptSessionProvider(sessionId);
  }

  @override
  TranscriptSessionProvider getProviderOverride(
    covariant TranscriptSessionProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'transcriptSessionProvider';
}

/// Returns the session with [sessionId], or `null` if it does not exist.
///
/// Copied from [transcriptSession].
class TranscriptSessionProvider
    extends AutoDisposeFutureProvider<TranscriptSession?> {
  /// Returns the session with [sessionId], or `null` if it does not exist.
  ///
  /// Copied from [transcriptSession].
  TranscriptSessionProvider(String sessionId)
    : this._internal(
        (ref) => transcriptSession(ref as TranscriptSessionRef, sessionId),
        from: transcriptSessionProvider,
        name: r'transcriptSessionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$transcriptSessionHash,
        dependencies: TranscriptSessionFamily._dependencies,
        allTransitiveDependencies:
            TranscriptSessionFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  TranscriptSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  Override overrideWith(
    FutureOr<TranscriptSession?> Function(TranscriptSessionRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TranscriptSessionProvider._internal(
        (ref) => create(ref as TranscriptSessionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<TranscriptSession?> createElement() {
    return _TranscriptSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptSessionProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TranscriptSessionRef on AutoDisposeFutureProviderRef<TranscriptSession?> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _TranscriptSessionProviderElement
    extends AutoDisposeFutureProviderElement<TranscriptSession?>
    with TranscriptSessionRef {
  _TranscriptSessionProviderElement(super.provider);

  @override
  String get sessionId => (origin as TranscriptSessionProvider).sessionId;
}

String _$transcriptSegmentsHash() =>
    r'0f63805b805e07db2c4a65860198ac2215246c0b';

/// Returns all segments for [sessionId] ordered by start time ascending.
///
/// Copied from [transcriptSegments].
@ProviderFor(transcriptSegments)
const transcriptSegmentsProvider = TranscriptSegmentsFamily();

/// Returns all segments for [sessionId] ordered by start time ascending.
///
/// Copied from [transcriptSegments].
class TranscriptSegmentsFamily
    extends Family<AsyncValue<List<TranscriptSegment>>> {
  /// Returns all segments for [sessionId] ordered by start time ascending.
  ///
  /// Copied from [transcriptSegments].
  const TranscriptSegmentsFamily();

  /// Returns all segments for [sessionId] ordered by start time ascending.
  ///
  /// Copied from [transcriptSegments].
  TranscriptSegmentsProvider call(String sessionId) {
    return TranscriptSegmentsProvider(sessionId);
  }

  @override
  TranscriptSegmentsProvider getProviderOverride(
    covariant TranscriptSegmentsProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'transcriptSegmentsProvider';
}

/// Returns all segments for [sessionId] ordered by start time ascending.
///
/// Copied from [transcriptSegments].
class TranscriptSegmentsProvider
    extends AutoDisposeFutureProvider<List<TranscriptSegment>> {
  /// Returns all segments for [sessionId] ordered by start time ascending.
  ///
  /// Copied from [transcriptSegments].
  TranscriptSegmentsProvider(String sessionId)
    : this._internal(
        (ref) => transcriptSegments(ref as TranscriptSegmentsRef, sessionId),
        from: transcriptSegmentsProvider,
        name: r'transcriptSegmentsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$transcriptSegmentsHash,
        dependencies: TranscriptSegmentsFamily._dependencies,
        allTransitiveDependencies:
            TranscriptSegmentsFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  TranscriptSegmentsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  Override overrideWith(
    FutureOr<List<TranscriptSegment>> Function(TranscriptSegmentsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TranscriptSegmentsProvider._internal(
        (ref) => create(ref as TranscriptSegmentsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TranscriptSegment>> createElement() {
    return _TranscriptSegmentsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptSegmentsProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TranscriptSegmentsRef
    on AutoDisposeFutureProviderRef<List<TranscriptSegment>> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _TranscriptSegmentsProviderElement
    extends AutoDisposeFutureProviderElement<List<TranscriptSegment>>
    with TranscriptSegmentsRef {
  _TranscriptSegmentsProviderElement(super.provider);

  @override
  String get sessionId => (origin as TranscriptSegmentsProvider).sessionId;
}

String _$transcriptSettingsNotifierHash() =>
    r'd900138569b30a1822856961657bb9f30e3bccd8';

/// Manages [TranscriptSettings] persistence via `SharedPreferences`.
///
/// Copied from [TranscriptSettingsNotifier].
@ProviderFor(TranscriptSettingsNotifier)
final transcriptSettingsNotifierProvider =
    NotifierProvider<TranscriptSettingsNotifier, TranscriptSettings>.internal(
      TranscriptSettingsNotifier.new,
      name: r'transcriptSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptSettingsNotifier = Notifier<TranscriptSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
