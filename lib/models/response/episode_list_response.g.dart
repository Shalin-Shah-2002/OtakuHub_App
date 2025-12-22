// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpisodeListResponse _$EpisodeListResponseFromJson(Map<String, dynamic> json) =>
    EpisodeListResponse(
      success: json['success'] as bool?,
      count: (json['count'] as num?)?.toInt(),
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => EpisodeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$EpisodeListResponseToJson(
  EpisodeListResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'count': instance.count,
  'data': instance.data,
};
