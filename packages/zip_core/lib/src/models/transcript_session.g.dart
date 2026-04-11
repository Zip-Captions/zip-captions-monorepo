// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TranscriptSessionImpl _$$TranscriptSessionImplFromJson(
  Map<String, dynamic> json,
) => _$TranscriptSessionImpl(
  sessionId: json['sessionId'] as String,
  date: DateTime.parse(json['date'] as String),
  durationMs: (json['durationMs'] as num).toInt(),
  segmentCount: (json['segmentCount'] as num).toInt(),
  title: json['title'] as String?,
);

Map<String, dynamic> _$$TranscriptSessionImplToJson(
  _$TranscriptSessionImpl instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'date': instance.date.toIso8601String(),
  'durationMs': instance.durationMs,
  'segmentCount': instance.segmentCount,
  'title': instance.title,
};
