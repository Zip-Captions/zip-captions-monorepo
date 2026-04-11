// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_segment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TranscriptSegmentImpl _$$TranscriptSegmentImplFromJson(
  Map<String, dynamic> json,
) => _$TranscriptSegmentImpl(
  segmentId: json['segmentId'] as String,
  sessionId: json['sessionId'] as String,
  text: json['text'] as String,
  sourceId: json['sourceId'] as String,
  startTimeMs: (json['startTimeMs'] as num).toInt(),
  endTimeMs: (json['endTimeMs'] as num).toInt(),
);

Map<String, dynamic> _$$TranscriptSegmentImplToJson(
  _$TranscriptSegmentImpl instance,
) => <String, dynamic>{
  'segmentId': instance.segmentId,
  'sessionId': instance.sessionId,
  'text': instance.text,
  'sourceId': instance.sourceId,
  'startTimeMs': instance.startTimeMs,
  'endTimeMs': instance.endTimeMs,
};
