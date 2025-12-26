/// Response model for the download API endpoint
class DownloadResponse {
  final bool success;
  final String episodeId;
  final String serverType;
  final int totalOptions;
  final List<DownloadOption> downloadOptions;
  final DownloadRecommendation? recommended;

  DownloadResponse({
    required this.success,
    required this.episodeId,
    required this.serverType,
    required this.totalOptions,
    required this.downloadOptions,
    this.recommended,
  });

  factory DownloadResponse.fromJson(Map<String, dynamic> json) {
    return DownloadResponse(
      success: json['success'] ?? false,
      episodeId: json['episode_id']?.toString() ?? '',
      serverType: json['server_type'] ?? 'sub',
      totalOptions: json['total_options'] ?? 0,
      downloadOptions: (json['download_options'] as List? ?? [])
          .map((e) => DownloadOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommended: json['recommended'] != null
          ? DownloadRecommendation.fromJson(json['recommended'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'episode_id': episodeId,
      'server_type': serverType,
      'total_options': totalOptions,
      'download_options': downloadOptions.map((e) => e.toJson()).toList(),
      'recommended': recommended?.toJson(),
    };
  }

  /// Get the best download option (prefers proxy URL)
  DownloadOption? get bestOption {
    if (downloadOptions.isEmpty) return null;

    // Prefer options with proxy URL
    final withProxy = downloadOptions
        .where((o) => o.proxyUrl.isNotEmpty)
        .toList();
    if (withProxy.isNotEmpty) return withProxy.first;

    // Fall back to first option with direct URL
    final withDirect = downloadOptions
        .where((o) => o.directUrl.isNotEmpty)
        .toList();
    if (withDirect.isNotEmpty) return withDirect.first;

    return downloadOptions.first;
  }
}

/// Individual download option from a server
class DownloadOption {
  final String server;
  final String quality;
  final String type;
  final bool isM3u8;
  final String directUrl;
  final String proxyUrl;
  final Map<String, String> headers;
  final List<DownloadSubtitle> subtitles;

  DownloadOption({
    required this.server,
    required this.quality,
    required this.type,
    required this.isM3u8,
    required this.directUrl,
    required this.proxyUrl,
    required this.headers,
    required this.subtitles,
  });

  factory DownloadOption.fromJson(Map<String, dynamic> json) {
    return DownloadOption(
      server: json['server'] ?? '',
      quality: json['quality'] ?? 'auto',
      type: json['type'] ?? 'hls',
      isM3u8: json['is_m3u8'] ?? true,
      directUrl: json['direct_url'] ?? '',
      proxyUrl: json['proxy_url'] ?? '',
      headers: Map<String, String>.from(json['headers'] ?? {}),
      subtitles: (json['subtitles'] as List? ?? [])
          .map((e) => DownloadSubtitle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'server': server,
      'quality': quality,
      'type': type,
      'is_m3u8': isM3u8,
      'direct_url': directUrl,
      'proxy_url': proxyUrl,
      'headers': headers,
      'subtitles': subtitles.map((e) => e.toJson()).toList(),
    };
  }

  /// Get the best URL to use for downloading
  String get downloadUrl => proxyUrl.isNotEmpty ? proxyUrl : directUrl;

  /// Check if headers are needed (only for direct URL)
  bool get needsHeaders => proxyUrl.isEmpty && directUrl.isNotEmpty;
}

/// Subtitle information for download
class DownloadSubtitle {
  final String file;
  final String label;
  final String kind;

  DownloadSubtitle({
    required this.file,
    required this.label,
    required this.kind,
  });

  factory DownloadSubtitle.fromJson(Map<String, dynamic> json) {
    return DownloadSubtitle(
      file: json['file'] ?? '',
      label: json['label'] ?? 'Unknown',
      kind: json['kind'] ?? 'captions',
    );
  }

  Map<String, dynamic> toJson() {
    return {'file': file, 'label': label, 'kind': kind};
  }
}

/// Recommended download method from API
class DownloadRecommendation {
  final String method;
  final String reason;

  DownloadRecommendation({required this.method, required this.reason});

  factory DownloadRecommendation.fromJson(Map<String, dynamic> json) {
    return DownloadRecommendation(
      method: json['method'] ?? 'proxy_url',
      reason: json['reason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'method': method, 'reason': reason};
  }
}
