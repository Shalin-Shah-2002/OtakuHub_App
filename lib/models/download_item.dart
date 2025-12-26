import 'dart:convert';

/// Status of a download
enum DownloadStatus { pending, downloading, completed, failed, paused }

/// Model for a downloaded subtitle
class DownloadedSubtitle {
  final String label;
  final String language;
  final String filePath;

  DownloadedSubtitle({
    required this.label,
    required this.language,
    required this.filePath,
  });

  factory DownloadedSubtitle.fromJson(Map<String, dynamic> json) {
    return DownloadedSubtitle(
      label: json['label'] as String? ?? 'Unknown',
      language: json['language'] as String? ?? 'en',
      filePath: json['filePath'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'language': language,
    'filePath': filePath,
  };
}

/// Model for a downloaded episode
class DownloadItem {
  final String animeSlug;
  final String animeTitle;
  final String? animeThumbnail;
  final String episodeId;
  final int episodeNumber;
  final String? episodeTitle;
  final String serverType; // 'sub' or 'dub'
  final String? filePath; // Local file path after download
  final String? streamUrl; // Original stream URL
  final DateTime downloadedAt;
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  int? fileSize; // in bytes
  String? errorMessage;
  final List<DownloadedSubtitle> subtitles; // Downloaded subtitle files

  DownloadItem({
    required this.animeSlug,
    required this.animeTitle,
    this.animeThumbnail,
    required this.episodeId,
    required this.episodeNumber,
    this.episodeTitle,
    required this.serverType,
    this.filePath,
    this.streamUrl,
    required this.downloadedAt,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.fileSize,
    this.errorMessage,
    this.subtitles = const [],
  });

  /// Unique key for this download
  String get key => '${animeSlug}_ep${episodeNumber}_$serverType';

  /// Create from JSON
  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      animeSlug: json['animeSlug'] as String,
      animeTitle: json['animeTitle'] as String,
      animeThumbnail: json['animeThumbnail'] as String?,
      episodeId: json['episodeId'] as String,
      episodeNumber: json['episodeNumber'] as int,
      episodeTitle: json['episodeTitle'] as String?,
      serverType: json['serverType'] as String? ?? 'sub',
      filePath: json['filePath'] as String?,
      streamUrl: json['streamUrl'] as String?,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      fileSize: json['fileSize'] as int?,
      errorMessage: json['errorMessage'] as String?,
      subtitles:
          (json['subtitles'] as List?)
              ?.map(
                (s) => DownloadedSubtitle.fromJson(s as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'animeSlug': animeSlug,
      'animeTitle': animeTitle,
      'animeThumbnail': animeThumbnail,
      'episodeId': episodeId,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'serverType': serverType,
      'filePath': filePath,
      'streamUrl': streamUrl,
      'downloadedAt': downloadedAt.toIso8601String(),
      'status': status.name,
      'progress': progress,
      'fileSize': fileSize,
      'errorMessage': errorMessage,
      'subtitles': subtitles.map((s) => s.toJson()).toList(),
    };
  }

  /// Create from JSON string
  factory DownloadItem.fromJsonString(String jsonString) {
    return DownloadItem.fromJson(
      json.decode(jsonString) as Map<String, dynamic>,
    );
  }

  /// Convert to JSON string
  String toJsonString() => json.encode(toJson());

  /// Copy with updated values
  DownloadItem copyWith({
    String? animeSlug,
    String? animeTitle,
    String? animeThumbnail,
    String? episodeId,
    int? episodeNumber,
    String? episodeTitle,
    String? serverType,
    String? filePath,
    String? streamUrl,
    DateTime? downloadedAt,
    DownloadStatus? status,
    double? progress,
    int? fileSize,
    String? errorMessage,
    List<DownloadedSubtitle>? subtitles,
  }) {
    return DownloadItem(
      animeSlug: animeSlug ?? this.animeSlug,
      animeTitle: animeTitle ?? this.animeTitle,
      animeThumbnail: animeThumbnail ?? this.animeThumbnail,
      episodeId: episodeId ?? this.episodeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      serverType: serverType ?? this.serverType,
      filePath: filePath ?? this.filePath,
      streamUrl: streamUrl ?? this.streamUrl,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      fileSize: fileSize ?? this.fileSize,
      errorMessage: errorMessage ?? this.errorMessage,
      subtitles: subtitles ?? this.subtitles,
    );
  }

  /// Get human-readable file size
  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
