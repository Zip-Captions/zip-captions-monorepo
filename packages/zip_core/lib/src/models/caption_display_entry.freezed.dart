// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'caption_display_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CaptionDisplayEntry {
  /// Unique entry identifier (UUID).
  String get entryId => throw _privateConstructorUsedError;

  /// Session this entry belongs to.
  String get sessionId => throw _privateConstructorUsedError;

  /// Caption text. May be empty for interim results.
  String get text => throw _privateConstructorUsedError;

  /// Whether this is a committed utterance (`true`) or in-progress
  /// interim (`false`).
  bool get isFinal => throw _privateConstructorUsedError;

  /// Input source identifier; the widget layer maps this to
  /// [AudioInputVisualStyle] via [AudioInputSettingsProvider].
  String get sourceId => throw _privateConstructorUsedError;

  /// When the result was recognized (UTC).
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Create a copy of CaptionDisplayEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CaptionDisplayEntryCopyWith<CaptionDisplayEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaptionDisplayEntryCopyWith<$Res> {
  factory $CaptionDisplayEntryCopyWith(
    CaptionDisplayEntry value,
    $Res Function(CaptionDisplayEntry) then,
  ) = _$CaptionDisplayEntryCopyWithImpl<$Res, CaptionDisplayEntry>;
  @useResult
  $Res call({
    String entryId,
    String sessionId,
    String text,
    bool isFinal,
    String sourceId,
    DateTime timestamp,
  });
}

/// @nodoc
class _$CaptionDisplayEntryCopyWithImpl<$Res, $Val extends CaptionDisplayEntry>
    implements $CaptionDisplayEntryCopyWith<$Res> {
  _$CaptionDisplayEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CaptionDisplayEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryId = null,
    Object? sessionId = null,
    Object? text = null,
    Object? isFinal = null,
    Object? sourceId = null,
    Object? timestamp = null,
  }) {
    return _then(
      _value.copyWith(
            entryId: null == entryId
                ? _value.entryId
                : entryId // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            isFinal: null == isFinal
                ? _value.isFinal
                : isFinal // ignore: cast_nullable_to_non_nullable
                      as bool,
            sourceId: null == sourceId
                ? _value.sourceId
                : sourceId // ignore: cast_nullable_to_non_nullable
                      as String,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CaptionDisplayEntryImplCopyWith<$Res>
    implements $CaptionDisplayEntryCopyWith<$Res> {
  factory _$$CaptionDisplayEntryImplCopyWith(
    _$CaptionDisplayEntryImpl value,
    $Res Function(_$CaptionDisplayEntryImpl) then,
  ) = __$$CaptionDisplayEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String entryId,
    String sessionId,
    String text,
    bool isFinal,
    String sourceId,
    DateTime timestamp,
  });
}

/// @nodoc
class __$$CaptionDisplayEntryImplCopyWithImpl<$Res>
    extends _$CaptionDisplayEntryCopyWithImpl<$Res, _$CaptionDisplayEntryImpl>
    implements _$$CaptionDisplayEntryImplCopyWith<$Res> {
  __$$CaptionDisplayEntryImplCopyWithImpl(
    _$CaptionDisplayEntryImpl _value,
    $Res Function(_$CaptionDisplayEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CaptionDisplayEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryId = null,
    Object? sessionId = null,
    Object? text = null,
    Object? isFinal = null,
    Object? sourceId = null,
    Object? timestamp = null,
  }) {
    return _then(
      _$CaptionDisplayEntryImpl(
        entryId: null == entryId
            ? _value.entryId
            : entryId // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        isFinal: null == isFinal
            ? _value.isFinal
            : isFinal // ignore: cast_nullable_to_non_nullable
                  as bool,
        sourceId: null == sourceId
            ? _value.sourceId
            : sourceId // ignore: cast_nullable_to_non_nullable
                  as String,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$CaptionDisplayEntryImpl implements _CaptionDisplayEntry {
  const _$CaptionDisplayEntryImpl({
    required this.entryId,
    required this.sessionId,
    required this.text,
    required this.isFinal,
    required this.sourceId,
    required this.timestamp,
  });

  /// Unique entry identifier (UUID).
  @override
  final String entryId;

  /// Session this entry belongs to.
  @override
  final String sessionId;

  /// Caption text. May be empty for interim results.
  @override
  final String text;

  /// Whether this is a committed utterance (`true`) or in-progress
  /// interim (`false`).
  @override
  final bool isFinal;

  /// Input source identifier; the widget layer maps this to
  /// [AudioInputVisualStyle] via [AudioInputSettingsProvider].
  @override
  final String sourceId;

  /// When the result was recognized (UTC).
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'CaptionDisplayEntry(entryId: $entryId, sessionId: $sessionId, text: $text, isFinal: $isFinal, sourceId: $sourceId, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaptionDisplayEntryImpl &&
            (identical(other.entryId, entryId) || other.entryId == entryId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.isFinal, isFinal) || other.isFinal == isFinal) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    entryId,
    sessionId,
    text,
    isFinal,
    sourceId,
    timestamp,
  );

  /// Create a copy of CaptionDisplayEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CaptionDisplayEntryImplCopyWith<_$CaptionDisplayEntryImpl> get copyWith =>
      __$$CaptionDisplayEntryImplCopyWithImpl<_$CaptionDisplayEntryImpl>(
        this,
        _$identity,
      );
}

abstract class _CaptionDisplayEntry implements CaptionDisplayEntry {
  const factory _CaptionDisplayEntry({
    required final String entryId,
    required final String sessionId,
    required final String text,
    required final bool isFinal,
    required final String sourceId,
    required final DateTime timestamp,
  }) = _$CaptionDisplayEntryImpl;

  /// Unique entry identifier (UUID).
  @override
  String get entryId;

  /// Session this entry belongs to.
  @override
  String get sessionId;

  /// Caption text. May be empty for interim results.
  @override
  String get text;

  /// Whether this is a committed utterance (`true`) or in-progress
  /// interim (`false`).
  @override
  bool get isFinal;

  /// Input source identifier; the widget layer maps this to
  /// [AudioInputVisualStyle] via [AudioInputSettingsProvider].
  @override
  String get sourceId;

  /// When the result was recognized (UTC).
  @override
  DateTime get timestamp;

  /// Create a copy of CaptionDisplayEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CaptionDisplayEntryImplCopyWith<_$CaptionDisplayEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
