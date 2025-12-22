import 'package:json_annotation/json_annotation.dart';
import 'anime_model.dart';

part 'anime_list_response.g.dart';

@JsonSerializable()
class AnimeListResponse {
  final bool? success;
  final int? count;
  final int? page;
  final List<AnimeModel>? data;

  AnimeListResponse({this.success, this.count, this.page, this.data});

  factory AnimeListResponse.fromJson(Map<String, dynamic> json) =>
      _$AnimeListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AnimeListResponseToJson(this);
}
