/// Streaming response models for HiAnime API

class StreamResponse {
  final bool success;
  final String episodeId;
  final String serverType;
  final int totalStreams;
  final List<StreamData> streams;

  StreamResponse({
    required this.success,
    required this.episodeId,
    required this.serverType,
    required this.totalStreams,
    required this.streams,
  });

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    return StreamResponse(
      success: json['success'] ?? false,
      episodeId: json['episode_id']?.toString() ?? '',
      serverType: json['server_type']?.toString() ?? 'sub',
      totalStreams: json['total_streams'] ?? 0,
      streams:
          (json['streams'] as List?)
              ?.map((s) => StreamData.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'episode_id': episodeId,
    'server_type': serverType,
    'total_streams': totalStreams,
    'streams': streams.map((s) => s.toJson()).toList(),
  };
}

class StreamData {
  final String name;
  final String serverName;
  final String serverType;
  final List<StreamSource> sources;
  final List<Subtitle> subtitles;
  final SkipTimes? skips;
  final Map<String, String> headers;

  StreamData({
    required this.name,
    required this.serverName,
    required this.serverType,
    required this.sources,
    required this.subtitles,
    this.skips,
    required this.headers,
  });

  factory StreamData.fromJson(Map<String, dynamic> json) {
    return StreamData(
      name: json['name']?.toString() ?? '',
      serverName: json['server_name']?.toString() ?? '',
      serverType: json['server_type']?.toString() ?? '',
      sources:
          (json['sources'] as List?)
              ?.map((s) => StreamSource.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      subtitles:
          (json['subtitles'] as List?)
              ?.map((s) => Subtitle.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      skips: json['skips'] != null
          ? SkipTimes.fromJson(json['skips'] as Map<String, dynamic>)
          : null,
      headers: Map<String, String>.from(json['headers'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'server_name': serverName,
    'server_type': serverType,
    'sources': sources.map((s) => s.toJson()).toList(),
    'subtitles': subtitles.map((s) => s.toJson()).toList(),
    'skips': skips?.toJson(),
    'headers': headers,
  };
}

class StreamSource {
  final String file; // Direct m3u8 URL
  final String? proxyUrl; // Proxy URL (use if direct fails)
  final String type;
  final String quality;
  final bool isM3U8;
  final String host;

  StreamSource({
    required this.file,
    this.proxyUrl,
    required this.type,
    required this.quality,
    required this.isM3U8,
    required this.host,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      file: json['file']?.toString() ?? '',
      proxyUrl: json['proxy_url']?.toString(),
      type: json['type']?.toString() ?? 'hls',
      quality: json['quality']?.toString() ?? 'auto',
      isM3U8: json['isM3U8'] ?? true,
      host: json['host']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'file': file,
    'proxy_url': proxyUrl,
    'type': type,
    'quality': quality,
    'isM3U8': isM3U8,
    'host': host,
  };
}

class Subtitle {
  final String file;
  final String label;
  final String kind;

  Subtitle({required this.file, required this.label, required this.kind});

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      file: json['file']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Unknown',
      kind: json['kind']?.toString() ?? 'captions',
    );
  }

  Map<String, dynamic> toJson() => {'file': file, 'label': label, 'kind': kind};
}

class SkipTimes {
  final TimeRange? intro;
  final TimeRange? outro;

  SkipTimes({this.intro, this.outro});

  factory SkipTimes.fromJson(Map<String, dynamic> json) {
    return SkipTimes(
      intro: json['intro'] != null
          ? TimeRange.fromJson(json['intro'] as Map<String, dynamic>)
          : null,
      outro: json['outro'] != null
          ? TimeRange.fromJson(json['outro'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'intro': intro?.toJson(),
    'outro': outro?.toJson(),
  };
}

class TimeRange {
  final int start;
  final int end;

  TimeRange({required this.start, required this.end});

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(start: json['start'] ?? 0, end: json['end'] ?? 0);
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  Duration get startDuration => Duration(seconds: start);
  Duration get endDuration => Duration(seconds: end);
}
