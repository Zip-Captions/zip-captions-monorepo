// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcast_limits.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BroadcastLimits {
  /// Maximum concurrent viewers.
  int get maxViewers => throw _privateConstructorUsedError;

  /// Not currently consumed by `ViewerAdmission` — reserved for a future
  /// presence-adjacent liveness check.
  Duration get presenceTimeout => throw _privateConstructorUsedError;

  /// How long a disconnected viewer's slot is reserved for reclaim before
  /// being released to a new viewer (`business-rules.md` Rule 6).
  Duration get reconnectWindow => throw _privateConstructorUsedError;

  /// Create a copy of BroadcastLimits
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BroadcastLimitsCopyWith<BroadcastLimits> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BroadcastLimitsCopyWith<$Res> {
  factory $BroadcastLimitsCopyWith(
    BroadcastLimits value,
    $Res Function(BroadcastLimits) then,
  ) = _$BroadcastLimitsCopyWithImpl<$Res, BroadcastLimits>;
  @useResult
  $Res call({
    int maxViewers,
    Duration presenceTimeout,
    Duration reconnectWindow,
  });
}

/// @nodoc
class _$BroadcastLimitsCopyWithImpl<$Res, $Val extends BroadcastLimits>
    implements $BroadcastLimitsCopyWith<$Res> {
  _$BroadcastLimitsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BroadcastLimits
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxViewers = null,
    Object? presenceTimeout = null,
    Object? reconnectWindow = null,
  }) {
    return _then(
      _value.copyWith(
            maxViewers: null == maxViewers
                ? _value.maxViewers
                : maxViewers // ignore: cast_nullable_to_non_nullable
                      as int,
            presenceTimeout: null == presenceTimeout
                ? _value.presenceTimeout
                : presenceTimeout // ignore: cast_nullable_to_non_nullable
                      as Duration,
            reconnectWindow: null == reconnectWindow
                ? _value.reconnectWindow
                : reconnectWindow // ignore: cast_nullable_to_non_nullable
                      as Duration,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BroadcastLimitsImplCopyWith<$Res>
    implements $BroadcastLimitsCopyWith<$Res> {
  factory _$$BroadcastLimitsImplCopyWith(
    _$BroadcastLimitsImpl value,
    $Res Function(_$BroadcastLimitsImpl) then,
  ) = __$$BroadcastLimitsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int maxViewers,
    Duration presenceTimeout,
    Duration reconnectWindow,
  });
}

/// @nodoc
class __$$BroadcastLimitsImplCopyWithImpl<$Res>
    extends _$BroadcastLimitsCopyWithImpl<$Res, _$BroadcastLimitsImpl>
    implements _$$BroadcastLimitsImplCopyWith<$Res> {
  __$$BroadcastLimitsImplCopyWithImpl(
    _$BroadcastLimitsImpl _value,
    $Res Function(_$BroadcastLimitsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcastLimits
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxViewers = null,
    Object? presenceTimeout = null,
    Object? reconnectWindow = null,
  }) {
    return _then(
      _$BroadcastLimitsImpl(
        maxViewers: null == maxViewers
            ? _value.maxViewers
            : maxViewers // ignore: cast_nullable_to_non_nullable
                  as int,
        presenceTimeout: null == presenceTimeout
            ? _value.presenceTimeout
            : presenceTimeout // ignore: cast_nullable_to_non_nullable
                  as Duration,
        reconnectWindow: null == reconnectWindow
            ? _value.reconnectWindow
            : reconnectWindow // ignore: cast_nullable_to_non_nullable
                  as Duration,
      ),
    );
  }
}

/// @nodoc

class _$BroadcastLimitsImpl implements _BroadcastLimits {
  const _$BroadcastLimitsImpl({
    required this.maxViewers,
    required this.presenceTimeout,
    required this.reconnectWindow,
  });

  /// Maximum concurrent viewers.
  @override
  final int maxViewers;

  /// Not currently consumed by `ViewerAdmission` — reserved for a future
  /// presence-adjacent liveness check.
  @override
  final Duration presenceTimeout;

  /// How long a disconnected viewer's slot is reserved for reclaim before
  /// being released to a new viewer (`business-rules.md` Rule 6).
  @override
  final Duration reconnectWindow;

  @override
  String toString() {
    return 'BroadcastLimits(maxViewers: $maxViewers, presenceTimeout: $presenceTimeout, reconnectWindow: $reconnectWindow)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BroadcastLimitsImpl &&
            (identical(other.maxViewers, maxViewers) ||
                other.maxViewers == maxViewers) &&
            (identical(other.presenceTimeout, presenceTimeout) ||
                other.presenceTimeout == presenceTimeout) &&
            (identical(other.reconnectWindow, reconnectWindow) ||
                other.reconnectWindow == reconnectWindow));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, maxViewers, presenceTimeout, reconnectWindow);

  /// Create a copy of BroadcastLimits
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BroadcastLimitsImplCopyWith<_$BroadcastLimitsImpl> get copyWith =>
      __$$BroadcastLimitsImplCopyWithImpl<_$BroadcastLimitsImpl>(
        this,
        _$identity,
      );
}

abstract class _BroadcastLimits implements BroadcastLimits {
  const factory _BroadcastLimits({
    required final int maxViewers,
    required final Duration presenceTimeout,
    required final Duration reconnectWindow,
  }) = _$BroadcastLimitsImpl;

  /// Maximum concurrent viewers.
  @override
  int get maxViewers;

  /// Not currently consumed by `ViewerAdmission` — reserved for a future
  /// presence-adjacent liveness check.
  @override
  Duration get presenceTimeout;

  /// How long a disconnected viewer's slot is reserved for reclaim before
  /// being released to a new viewer (`business-rules.md` Rule 6).
  @override
  Duration get reconnectWindow;

  /// Create a copy of BroadcastLimits
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BroadcastLimitsImplCopyWith<_$BroadcastLimitsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
