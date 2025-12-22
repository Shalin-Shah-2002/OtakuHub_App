// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnimeModel _$AnimeModelFromJson(Map<String, dynamic> json) => AnimeModel(
  id: json['id'] as String?,
  slug: json['slug'] as String?,
  title: json['title'] as String?,
  url: json['url'] as String?,
  thumbnail: json['thumbnail'] as String?,
  type: json['type'] as String?,
  status: json['status'] as String?,
  duration: json['duration'] as String?,
  episodesSub: (json['episodes_sub'] as num?)?.toInt(),
  episodesDub: (json['episodes_dub'] as num?)?.toInt(),
  malScore: (json['mal_score'] as num?)?.toDouble(),
  synopsis: json['synopsis'] as String?,
  genres: (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
  studios: (json['studios'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$AnimeModelToJson(AnimeModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'url': instance.url,
      'thumbnail': instance.thumbnail,
      'type': instance.type,
      'status': instance.status,
      'duration': instance.duration,
      'episodes_sub': instance.episodesSub,
      'episodes_dub': instance.episodesDub,
      'mal_score': instance.malScore,
      'synopsis': instance.synopsis,
      'genres': instance.genres,
      'studios': instance.studios,
    };
