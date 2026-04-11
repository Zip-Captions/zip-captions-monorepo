// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcript_search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TranscriptSearchResult {
  /// The matching session's metadata.
  TranscriptSession get session => throw _privateConstructorUsedError;

  /// Matching excerpt strings from FTS5 `snippet()`, up to 3 per session.
  List<String> get snippets => throw _privateConstructorUsedError;

  /// BM25 relevance score (lower = more relevant in SQLite FTS5).
  double get relevanceScore => throw _privateConstructorUsedError;

  /// Create a copy of TranscriptSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranscriptSearchResultCopyWith<TranscriptSearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptSearchResultCopyWith<$Res> {
  factory $TranscriptSearchResultCopyWith(
    TranscriptSearchResult value,
    $Res Function(TranscriptSearchResult) then,
  ) = _$TranscriptSearchResultCopyWithImpl<$Res, TranscriptSearchResult>;
  @useResult
  $Res call({
    TranscriptSession session,
    List<String> snippets,
    double relevanceScore,
  });

  $TranscriptSessionCopyWith<$Res> get session;
}

/// @nodoc
class _$TranscriptSearchResultCopyWithImpl<
  $Res,
  $Val extends TranscriptSearchResult
>
    implements $TranscriptSearchResultCopyWith<$Res> {
  _$TranscriptSearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranscriptSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? snippets = null,
    Object? relevanceScore = null,
  }) {
    return _then(
      _value.copyWith(
            session: null == session
                ? _value.session
                : session // ignore: cast_nullable_to_non_nullable
                      as TranscriptSession,
            snippets: null == snippets
                ? _value.snippets
                : snippets // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            relevanceScore: null == relevanceScore
                ? _value.relevanceScore
                : relevanceScore // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }

  /// Create a copy of TranscriptSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TranscriptSessionCopyWith<$Res> get session {
    return $TranscriptSessionCopyWith<$Res>(_value.session, (value) {
      return _then(_value.copyWith(session: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TranscriptSearchResultImplCopyWith<$Res>
    implements $TranscriptSearchResultCopyWith<$Res> {
  factory _$$TranscriptSearchResultImplCopyWith(
    _$TranscriptSearchResultImpl value,
    $Res Function(_$TranscriptSearchResultImpl) then,
  ) = __$$TranscriptSearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    TranscriptSession session,
    List<String> snippets,
    double relevanceScore,
  });

  @override
  $TranscriptSessionCopyWith<$Res> get session;
}

/// @nodoc
class __$$TranscriptSearchResultImplCopyWithImpl<$Res>
    extends
        _$TranscriptSearchResultCopyWithImpl<$Res, _$TranscriptSearchResultImpl>
    implements _$$TranscriptSearchResultImplCopyWith<$Res> {
  __$$TranscriptSearchResultImplCopyWithImpl(
    _$TranscriptSearchResultImpl _value,
    $Res Function(_$TranscriptSearchResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TranscriptSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? snippets = null,
    Object? relevanceScore = null,
  }) {
    return _then(
      _$TranscriptSearchResultImpl(
        session: null == session
            ? _value.session
            : session // ignore: cast_nullable_to_non_nullable
                  as TranscriptSession,
        snippets: null == snippets
            ? _value._snippets
            : snippets // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        relevanceScore: null == relevanceScore
            ? _value.relevanceScore
            : relevanceScore // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$TranscriptSearchResultImpl implements _TranscriptSearchResult {
  const _$TranscriptSearchResultImpl({
    required this.session,
    required final List<String> snippets,
    required this.relevanceScore,
  }) : _snippets = snippets;

  /// The matching session's metadata.
  @override
  final TranscriptSession session;

  /// Matching excerpt strings from FTS5 `snippet()`, up to 3 per session.
  final List<String> _snippets;

  /// Matching excerpt strings from FTS5 `snippet()`, up to 3 per session.
  @override
  List<String> get snippets {
    if (_snippets is EqualUnmodifiableListView) return _snippets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_snippets);
  }

  /// BM25 relevance score (lower = more relevant in SQLite FTS5).
  @override
  final double relevanceScore;

  @override
  String toString() {
    return 'TranscriptSearchResult(session: $session, snippets: $snippets, relevanceScore: $relevanceScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptSearchResultImpl &&
            (identical(other.session, session) || other.session == session) &&
            const DeepCollectionEquality().equals(other._snippets, _snippets) &&
            (identical(other.relevanceScore, relevanceScore) ||
                other.relevanceScore == relevanceScore));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    session,
    const DeepCollectionEquality().hash(_snippets),
    relevanceScore,
  );

  /// Create a copy of TranscriptSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptSearchResultImplCopyWith<_$TranscriptSearchResultImpl>
  get copyWith =>
      __$$TranscriptSearchResultImplCopyWithImpl<_$TranscriptSearchResultImpl>(
        this,
        _$identity,
      );
}

abstract class _TranscriptSearchResult implements TranscriptSearchResult {
  const factory _TranscriptSearchResult({
    required final TranscriptSession session,
    required final List<String> snippets,
    required final double relevanceScore,
  }) = _$TranscriptSearchResultImpl;

  /// The matching session's metadata.
  @override
  TranscriptSession get session;

  /// Matching excerpt strings from FTS5 `snippet()`, up to 3 per session.
  @override
  List<String> get snippets;

  /// BM25 relevance score (lower = more relevant in SQLite FTS5).
  @override
  double get relevanceScore;

  /// Create a copy of TranscriptSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranscriptSearchResultImplCopyWith<_$TranscriptSearchResultImpl>
  get copyWith => throw _privateConstructorUsedError;
}
