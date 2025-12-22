import 'dart:convert';

/// Represents an item in watch history
class WatchHistoryItem {
  final String animeSlug;
  final String animeTitle;
  final String? animeThumbnail;
  final int episodeNumber;
  final String? episodeTitle;
  final String episodeUrl;
  final DateTime watchedAt;

  WatchHistoryItem({
    required this.animeSlug,
    required this.animeTitle,
    this.animeThumbnail,
    required this.episodeNumber,
    this.episodeTitle,
    required this.episodeUrl,
    required this.watchedAt,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      animeSlug: json['animeSlug'] ?? '',
      animeTitle: json['animeTitle'] ?? '',
      animeThumbnail: json['animeThumbnail'],
      episodeNumber: json['episodeNumber'] ?? 0,
      episodeTitle: json['episodeTitle'],
      episodeUrl: json['episodeUrl'] ?? '',
      watchedAt: DateTime.tryParse(json['watchedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'animeSlug': animeSlug,
    'animeTitle': animeTitle,
    'animeThumbnail': animeThumbnail,
    'episodeNumber': episodeNumber,
    'episodeTitle': episodeTitle,
    'episodeUrl': episodeUrl,
    'watchedAt': watchedAt.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  static WatchHistoryItem fromJsonString(String json) =>
      WatchHistoryItem.fromJson(jsonDecode(json));

  /// Unique key for this item (anime + episode)
  String get uniqueKey => '${animeSlug}_$episodeNumber';
}

/// Represents an anime in the watchlist
class WatchlistItem {
  final String slug;
  final String title;
  final String? thumbnail;
  final String? type;
  final double? malScore;
  final int? episodesSub;
  final DateTime addedAt;

  WatchlistItem({
    required this.slug,
    required this.title,
    this.thumbnail,
    this.type,
    this.malScore,
    this.episodesSub,
    required this.addedAt,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      type: json['type'],
      malScore: json['malScore']?.toDouble(),
      episodesSub: json['episodesSub'],
      addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'title': title,
    'thumbnail': thumbnail,
    'type': type,
    'malScore': malScore,
    'episodesSub': episodesSub,
    'addedAt': addedAt.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  static WatchlistItem fromJsonString(String json) =>
      WatchlistItem.fromJson(jsonDecode(json));
}
