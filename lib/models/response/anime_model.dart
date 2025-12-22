import 'package:json_annotation/json_annotation.dart';

part 'anime_model.g.dart';

@JsonSerializable()
class AnimeModel {
  final String? id;
  final String? slug;
  final String? title;
  final String? url;
  final String? thumbnail;
  final String? type;
  final String? status;
  final String? duration;

  @JsonKey(name: 'episodes_sub')
  final int? episodesSub;

  @JsonKey(name: 'episodes_dub')
  final int? episodesDub;

  @JsonKey(name: 'mal_score')
  final double? malScore;

  final String? synopsis;
  final List<String>? genres;
  final List<String>? studios;

  AnimeModel({
    this.id,
    this.slug,
    this.title,
    this.url,
    this.thumbnail,
    this.type,
    this.status,
    this.duration,
    this.episodesSub,
    this.episodesDub,
    this.malScore,
    this.synopsis,
    this.genres,
    this.studios,
  });

  factory AnimeModel.fromJson(Map<String, dynamic> json) =>
      _$AnimeModelFromJson(json);

  Map<String, dynamic> toJson() => _$AnimeModelToJson(this);
}
