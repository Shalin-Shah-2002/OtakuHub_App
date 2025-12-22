// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpisodeModel _$EpisodeModelFromJson(Map<String, dynamic> json) => EpisodeModel(
  number: (json['number'] as num?)?.toInt(),
  title: json['title'] as String?,
  url: json['url'] as String?,
  id: json['id'] as String?,
  japaneseTitle: json['japanese_title'] as String?,
  isFiller: json['is_filler'] as bool?,
);

Map<String, dynamic> _$EpisodeModelToJson(EpisodeModel instance) =>
    <String, dynamic>{
      'number': instance.number,
      'title': instance.title,
      'url': instance.url,
      'id': instance.id,
      'japanese_title': instance.japaneseTitle,
      'is_filler': instance.isFiller,
    };
