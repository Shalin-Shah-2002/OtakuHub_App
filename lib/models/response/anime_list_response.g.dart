// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnimeListResponse _$AnimeListResponseFromJson(Map<String, dynamic> json) =>
    AnimeListResponse(
      success: json['success'] as bool?,
      count: (json['count'] as num?)?.toInt(),
      page: (json['page'] as num?)?.toInt(),
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => AnimeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AnimeListResponseToJson(AnimeListResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'count': instance.count,
      'page': instance.page,
      'data': instance.data,
    };
