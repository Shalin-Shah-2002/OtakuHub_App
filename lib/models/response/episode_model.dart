import 'package:json_annotation/json_annotation.dart';

part 'episode_model.g.dart';

@JsonSerializable()
class EpisodeModel {
  final int? number;
  final String? title;
  final String? url;
  final String? id;

  @JsonKey(name: 'japanese_title')
  final String? japaneseTitle;

  @JsonKey(name: 'is_filler')
  final bool? isFiller;

  EpisodeModel({
    this.number,
    this.title,
    this.url,
    this.id,
    this.japaneseTitle,
    this.isFiller,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) =>
      _$EpisodeModelFromJson(json);

  Map<String, dynamic> toJson() => _$EpisodeModelToJson(this);
}
