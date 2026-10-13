// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_broadcast.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$LiveBroadcast {
  /// The broadcaster's permanent broadcast id — identical across all of
  /// this broadcaster's broadcasts.
  BroadcastId get broadcastId => throw _privateConstructorUsedError;

  /// The stable, shareable broadcast URL — always consistent with
  /// [broadcastId] (`BroadcastLink.toUrl`).
  Uri get url => throw _privateConstructorUsedError;

  /// A fresh id per `goLive()` — never an account identifier.
  String get sessionId => throw _privateConstructorUsedError;

  /// The validated name from `BroadcastSettings` (Rule 7).
  String get sessionName => throw _privateConstructorUsedError;

  /// This broadcast's current caption activity — drives the
  /// captions-inactive banner (FR-6.7).
  CaptionActivity get captionActivity => throw _privateConstructorUsedError;

  /// An exact mirror of `BroadcastTransport.viewers` — ack-confirmed
  /// viewers only (`business-rules.md` Rule 11).
  List<ViewerConnectionInfo> get viewers => throw _privateConstructorUsedError;

  /// This broadcast's viewer capacity ceiling
  /// (`defaultBroadcastLimits.maxViewers`).
  int get maxViewers => throw _privateConstructorUsedError;

  /// When this broadcast went live — stamped once, at `goLive()`'s F2-9
  /// step, never reused across sessions (Functional Design Q3, approved
  /// deviation from the fixed 7-field shape).
  DateTime get startedAt => throw _privateConstructorUsedError;

  /// Create a copy of LiveBroadcast
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveBroadcastCopyWith<LiveBroadcast> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveBroadcastCopyWith<$Res> {
  factory $LiveBroadcastCopyWith(
    LiveBroadcast value,
    $Res Function(LiveBroadcast) then,
  ) = _$LiveBroadcastCopyWithImpl<$Res, LiveBroadcast>;
  @useResult
  $Res call({
    BroadcastId broadcastId,
    Uri url,
    String sessionId,
    String sessionName,
    CaptionActivity captionActivity,
    List<ViewerConnectionInfo> viewers,
    int maxViewers,
    DateTime startedAt,
  });
}

/// @nodoc
class _$LiveBroadcastCopyWithImpl<$Res, $Val extends LiveBroadcast>
    implements $LiveBroadcastCopyWith<$Res> {
  _$LiveBroadcastCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveBroadcast
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? broadcastId = null,
    Object? url = null,
    Object? sessionId = null,
    Object? sessionName = null,
    Object? captionActivity = null,
    Object? viewers = null,
    Object? maxViewers = null,
    Object? startedAt = null,
  }) {
    return _then(
      _value.copyWith(
            broadcastId: null == broadcastId
                ? _value.broadcastId
                : broadcastId // ignore: cast_nullable_to_non_nullable
                      as BroadcastId,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as Uri,
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionName: null == sessionName
                ? _value.sessionName
                : sessionName // ignore: cast_nullable_to_non_nullable
                      as String,
            captionActivity: null == captionActivity
                ? _value.captionActivity
                : captionActivity // ignore: cast_nullable_to_non_nullable
                      as CaptionActivity,
            viewers: null == viewers
                ? _value.viewers
                : viewers // ignore: cast_nullable_to_non_nullable
                      as List<ViewerConnectionInfo>,
            maxViewers: null == maxViewers
                ? _value.maxViewers
                : maxViewers // ignore: cast_nullable_to_non_nullable
                      as int,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveBroadcastImplCopyWith<$Res>
    implements $LiveBroadcastCopyWith<$Res> {
  factory _$$LiveBroadcastImplCopyWith(
    _$LiveBroadcastImpl value,
    $Res Function(_$LiveBroadcastImpl) then,
  ) = __$$LiveBroadcastImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    BroadcastId broadcastId,
    Uri url,
    String sessionId,
    String sessionName,
    CaptionActivity captionActivity,
    List<ViewerConnectionInfo> viewers,
    int maxViewers,
    DateTime startedAt,
  });
}

/// @nodoc
class __$$LiveBroadcastImplCopyWithImpl<$Res>
    extends _$LiveBroadcastCopyWithImpl<$Res, _$LiveBroadcastImpl>
    implements _$$LiveBroadcastImplCopyWith<$Res> {
  __$$LiveBroadcastImplCopyWithImpl(
    _$LiveBroadcastImpl _value,
    $Res Function(_$LiveBroadcastImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveBroadcast
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? broadcastId = null,
    Object? url = null,
    Object? sessionId = null,
    Object? sessionName = null,
    Object? captionActivity = null,
    Object? viewers = null,
    Object? maxViewers = null,
    Object? startedAt = null,
  }) {
    return _then(
      _$LiveBroadcastImpl(
        broadcastId: null == broadcastId
            ? _value.broadcastId
            : broadcastId // ignore: cast_nullable_to_non_nullable
                  as BroadcastId,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as Uri,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionName: null == sessionName
            ? _value.sessionName
            : sessionName // ignore: cast_nullable_to_non_nullable
                  as String,
        captionActivity: null == captionActivity
            ? _value.captionActivity
            : captionActivity // ignore: cast_nullable_to_non_nullable
                  as CaptionActivity,
        viewers: null == viewers
            ? _value._viewers
            : viewers // ignore: cast_nullable_to_non_nullable
                  as List<ViewerConnectionInfo>,
        maxViewers: null == maxViewers
            ? _value.maxViewers
            : maxViewers // ignore: cast_nullable_to_non_nullable
                  as int,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$LiveBroadcastImpl implements _LiveBroadcast {
  const _$LiveBroadcastImpl({
    required this.broadcastId,
    required this.url,
    required this.sessionId,
    required this.sessionName,
    required this.captionActivity,
    required final List<ViewerConnectionInfo> viewers,
    required this.maxViewers,
    required this.startedAt,
  }) : _viewers = viewers;

  /// The broadcaster's permanent broadcast id — identical across all of
  /// this broadcaster's broadcasts.
  @override
  final BroadcastId broadcastId;

  /// The stable, shareable broadcast URL — always consistent with
  /// [broadcastId] (`BroadcastLink.toUrl`).
  @override
  final Uri url;

  /// A fresh id per `goLive()` — never an account identifier.
  @override
  final String sessionId;

  /// The validated name from `BroadcastSettings` (Rule 7).
  @override
  final String sessionName;

  /// This broadcast's current caption activity — drives the
  /// captions-inactive banner (FR-6.7).
  @override
  final CaptionActivity captionActivity;

  /// An exact mirror of `BroadcastTransport.viewers` — ack-confirmed
  /// viewers only (`business-rules.md` Rule 11).
  final List<ViewerConnectionInfo> _viewers;

  /// An exact mirror of `BroadcastTransport.viewers` — ack-confirmed
  /// viewers only (`business-rules.md` Rule 11).
  @override
  List<ViewerConnectionInfo> get viewers {
    if (_viewers is EqualUnmodifiableListView) return _viewers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_viewers);
  }

  /// This broadcast's viewer capacity ceiling
  /// (`defaultBroadcastLimits.maxViewers`).
  @override
  final int maxViewers;

  /// When this broadcast went live — stamped once, at `goLive()`'s F2-9
  /// step, never reused across sessions (Functional Design Q3, approved
  /// deviation from the fixed 7-field shape).
  @override
  final DateTime startedAt;

  @override
  String toString() {
    return 'LiveBroadcast(broadcastId: $broadcastId, url: $url, sessionId: $sessionId, sessionName: $sessionName, captionActivity: $captionActivity, viewers: $viewers, maxViewers: $maxViewers, startedAt: $startedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveBroadcastImpl &&
            (identical(other.broadcastId, broadcastId) ||
                other.broadcastId == broadcastId) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            (identical(other.captionActivity, captionActivity) ||
                other.captionActivity == captionActivity) &&
            const DeepCollectionEquality().equals(other._viewers, _viewers) &&
            (identical(other.maxViewers, maxViewers) ||
                other.maxViewers == maxViewers) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    broadcastId,
    url,
    sessionId,
    sessionName,
    captionActivity,
    const DeepCollectionEquality().hash(_viewers),
    maxViewers,
    startedAt,
  );

  /// Create a copy of LiveBroadcast
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveBroadcastImplCopyWith<_$LiveBroadcastImpl> get copyWith =>
      __$$LiveBroadcastImplCopyWithImpl<_$LiveBroadcastImpl>(this, _$identity);
}

abstract class _LiveBroadcast implements LiveBroadcast {
  const factory _LiveBroadcast({
    required final BroadcastId broadcastId,
    required final Uri url,
    required final String sessionId,
    required final String sessionName,
    required final CaptionActivity captionActivity,
    required final List<ViewerConnectionInfo> viewers,
    required final int maxViewers,
    required final DateTime startedAt,
  }) = _$LiveBroadcastImpl;

  /// The broadcaster's permanent broadcast id — identical across all of
  /// this broadcaster's broadcasts.
  @override
  BroadcastId get broadcastId;

  /// The stable, shareable broadcast URL — always consistent with
  /// [broadcastId] (`BroadcastLink.toUrl`).
  @override
  Uri get url;

  /// A fresh id per `goLive()` — never an account identifier.
  @override
  String get sessionId;

  /// The validated name from `BroadcastSettings` (Rule 7).
  @override
  String get sessionName;

  /// This broadcast's current caption activity — drives the
  /// captions-inactive banner (FR-6.7).
  @override
  CaptionActivity get captionActivity;

  /// An exact mirror of `BroadcastTransport.viewers` — ack-confirmed
  /// viewers only (`business-rules.md` Rule 11).
  @override
  List<ViewerConnectionInfo> get viewers;

  /// This broadcast's viewer capacity ceiling
  /// (`defaultBroadcastLimits.maxViewers`).
  @override
  int get maxViewers;

  /// When this broadcast went live — stamped once, at `goLive()`'s F2-9
  /// step, never reused across sessions (Functional Design Q3, approved
  /// deviation from the fixed 7-field shape).
  @override
  DateTime get startedAt;

  /// Create a copy of LiveBroadcast
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveBroadcastImplCopyWith<_$LiveBroadcastImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
