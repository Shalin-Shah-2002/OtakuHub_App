import 'package:json_annotation/json_annotation.dart';

part 'episode_model.g.dart';

@JsonSerializable()
class EpisodeModel {
  final int? number;
  final String? title;
  final String? url;

  // Support both 'id' and 'episode_id' from API
  @JsonKey(name: 'episode_id', defaultValue: null)
  final String? episodeId;

  // Also keep 'id' field for backwards compatibility
  final String? id;

  @JsonKey(name: 'japanese_title')
  final String? japaneseTitle;

  @JsonKey(name: 'is_filler')
  final bool? isFiller;

  EpisodeModel({
    this.number,
    this.title,
    this.url,
    this.episodeId,
    this.id,
    this.japaneseTitle,
    this.isFiller,
  });

  /// Get the episode ID for streaming - prefers episode_id, falls back to id
  String? get streamingId => episodeId ?? id;

  factory EpisodeModel.fromJson(Map<String, dynamic> json) =>
      _$EpisodeModelFromJson(json);

  Map<String, dynamic> toJson() => _$EpisodeModelToJson(this);
}
