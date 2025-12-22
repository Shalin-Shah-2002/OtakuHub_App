import 'package:json_annotation/json_annotation.dart';
import 'episode_model.dart';

part 'episode_list_response.g.dart';

@JsonSerializable()
class EpisodeListResponse {
  final bool? success;
  final int? count;
  final List<EpisodeModel>? data;

  EpisodeListResponse({this.success, this.count, this.data});

  factory EpisodeListResponse.fromJson(Map<String, dynamic> json) =>
      _$EpisodeListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$EpisodeListResponseToJson(this);
}
