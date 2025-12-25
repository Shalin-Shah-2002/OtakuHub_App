import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import '../models/response/anime_model.dart';
import '../models/response/episode_model.dart';
import '../models/response/stream_response.dart';
import '../utils/logger_service.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Service for managing episode downloads
class DownloadService extends GetxService {
  static const String _tag = 'DownloadService';
  static const String _downloadsKey = 'downloads';

  late SharedPreferences _prefs;
  final ApiService _apiService = ApiService();

  // Reactive list for UI updates
  final RxList<DownloadItem> downloads = <DownloadItem>[].obs;

  // Current download queue
  final RxList<String> downloadQueue = <String>[].obs;

  // Active download
  final Rx<String?> activeDownloadKey = Rx<String?>(null);

  // Download cancellation tokens
  final Map<String, bool> _cancelTokens = {};

  /// Initialize the service
  Future<DownloadService> init() async {
    logger.i(_tag, 'Initializing DownloadService');
    _prefs = await SharedPreferences.getInstance();
    await _loadDownloads();
    logger.i(
      _tag,
      'DownloadService initialized - Downloads: ${downloads.length}',
    );
    return this;
  }

  /// Get downloads directory
  Future<Directory> get _downloadsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _loadDownloads() async {
    try {
      final jsonList = _prefs.getStringList(_downloadsKey) ?? [];
      downloads.value = jsonList
          .map((json) => DownloadItem.fromJsonString(json))
          .toList();

      // Sort by download date (newest first)
      downloads.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

      logger.d(_tag, 'Loaded ${downloads.length} downloads');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Failed to load downloads',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveDownloads() async {
    try {
      final jsonList = downloads.map((item) => item.toJsonString()).toList();
      await _prefs.setStringList(_downloadsKey, jsonList);
      logger.d(_tag, 'Saved ${downloads.length} downloads');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Failed to save downloads',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Refresh downloads list
  Future<void> refreshDownloads() async {
    await _loadDownloads();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DOWNLOAD MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════════

  /// Check if an episode is downloaded
  bool isDownloaded(String animeSlug, int episodeNumber, String serverType) {
    final key = '${animeSlug}_ep${episodeNumber}_$serverType';
    return downloads.any(
      (d) => d.key == key && d.status == DownloadStatus.completed,
    );
  }

  /// Check if an episode is downloading
  bool isDownloading(String animeSlug, int episodeNumber, String serverType) {
    final key = '${animeSlug}_ep${episodeNumber}_$serverType';
    return downloads.any(
      (d) =>
          d.key == key &&
          (d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.pending),
    );
  }

  /// Get download item by key
  DownloadItem? getDownload(
    String animeSlug,
    int episodeNumber,
    String serverType,
  ) {
    final key = '${animeSlug}_ep${episodeNumber}_$serverType';
    try {
      return downloads.firstWhere((d) => d.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Get all downloads for an anime (grouped)
  List<DownloadItem> getDownloadsForAnime(String animeSlug) {
    return downloads.where((d) => d.animeSlug == animeSlug).toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }

  /// Get unique anime slugs from downloads
  List<String> get downloadedAnimeSlugs {
    return downloads
        .where((d) => d.status == DownloadStatus.completed)
        .map((d) => d.animeSlug)
        .toSet()
        .toList();
  }

  /// Get anime info from downloads
  Map<String, dynamic> getAnimeInfo(String animeSlug) {
    final animeDownloads = getDownloadsForAnime(animeSlug);
    if (animeDownloads.isEmpty) return {};

    final first = animeDownloads.first;
    final completedCount = animeDownloads
        .where((d) => d.status == DownloadStatus.completed)
        .length;

    return {
      'slug': animeSlug,
      'title': first.animeTitle,
      'thumbnail': first.animeThumbnail,
      'episodeCount': completedCount,
      'downloads': animeDownloads,
    };
  }

  /// Start download for an episode
  Future<void> startDownload({
    required AnimeModel anime,
    required EpisodeModel episode,
    required String serverType,
  }) async {
    final key = '${anime.slug}_ep${episode.number}_$serverType';

    // Check if already downloading or downloaded
    final existing = downloads.where((d) => d.key == key).toList();
    if (existing.isNotEmpty) {
      final existingItem = existing.first;
      if (existingItem.status == DownloadStatus.completed) {
        Get.snackbar(
          'Already Downloaded',
          'Episode ${episode.number} is already downloaded',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      if (existingItem.status == DownloadStatus.downloading ||
          existingItem.status == DownloadStatus.pending) {
        Get.snackbar(
          'Download in Progress',
          'Episode ${episode.number} is already being downloaded',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    // Create download item
    final downloadItem = DownloadItem(
      animeSlug: anime.slug ?? '',
      animeTitle: anime.title ?? 'Unknown',
      animeThumbnail: anime.thumbnail,
      episodeId: episode.streamingId ?? episode.id ?? '',
      episodeNumber: episode.number ?? 0,
      episodeTitle: episode.title,
      serverType: serverType,
      downloadedAt: DateTime.now(),
      status: DownloadStatus.pending,
    );

    // Add to downloads list
    downloads.removeWhere(
      (d) => d.key == key,
    ); // Remove any existing failed/cancelled
    downloads.insert(0, downloadItem);
    await _saveDownloads();

    // Add to queue
    downloadQueue.add(key);

    Get.snackbar(
      'Download Started',
      'Episode ${episode.number} added to download queue',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );

    // Process queue
    _processDownloadQueue();

    logger.logUserAction(
      'Started download',
      details: {
        'anime': anime.slug,
        'episode': episode.number,
        'serverType': serverType,
      },
    );
  }

  /// Process download queue
  Future<void> _processDownloadQueue() async {
    if (activeDownloadKey.value != null) return; // Already downloading
    if (downloadQueue.isEmpty) return;

    final key = downloadQueue.removeAt(0);
    activeDownloadKey.value = key;
    _cancelTokens[key] = false;

    try {
      final downloadIndex = downloads.indexWhere((d) => d.key == key);
      if (downloadIndex == -1) {
        activeDownloadKey.value = null;
        _processDownloadQueue();
        return;
      }

      final download = downloads[downloadIndex];

      // Update status
      downloads[downloadIndex] = download.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.0,
      );
      await _saveDownloads();

      // Fetch stream URL
      final streamResponse = await _apiService.getStreamingLinks(
        episodeId: download.episodeId,
        serverType: download.serverType,
      );

      if (_cancelTokens[key] == true) {
        _handleCancellation(key);
        return;
      }

      // Get the video URL
      String? videoUrl = _extractVideoUrl(streamResponse);

      if (videoUrl == null) {
        throw Exception('No video URL found');
      }

      // Download the video
      await _downloadVideo(key, videoUrl);
    } catch (e, stackTrace) {
      logger.e(_tag, 'Download failed', error: e, stackTrace: stackTrace);

      final downloadIndex = downloads.indexWhere((d) => d.key == key);
      if (downloadIndex != -1) {
        downloads[downloadIndex] = downloads[downloadIndex].copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        await _saveDownloads();
      }

      Get.snackbar(
        'Download Failed',
        'Failed to download episode',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      activeDownloadKey.value = null;
      _cancelTokens.remove(key);
      _processDownloadQueue();
    }
  }

  /// Extract video URL from stream response
  String? _extractVideoUrl(StreamResponse? response) {
    if (response == null) return null;

    // Get base URL for relative URLs
    final storageService = Get.find<StorageService>();
    final baseUrl = storageService.getBaseUrlOrDefault();

    // Try to get URL from streams
    for (final stream in response.streams) {
      for (final source in stream.sources) {
        if (source.proxyUrl != null && source.proxyUrl!.isNotEmpty) {
          String url = source.proxyUrl!;
          // Check if it's a relative URL and prepend base URL
          if (url.startsWith('/')) {
            url = baseUrl + url;
          }
          return url;
        }
        if (source.file.isNotEmpty) {
          String url = source.file;
          // Check if it's a relative URL and prepend base URL
          if (url.startsWith('/')) {
            url = baseUrl + url;
          }
          return url;
        }
      }
    }
    return null;
  }

  // Dio instance for downloads
  final Dio _dio = Dio();

  // Active cancel tokens for Dio
  final Map<String, CancelToken> _dioCancelTokens = {};

  /// Download video file
  Future<void> _downloadVideo(String key, String url) async {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex == -1) return;

    final download = downloads[downloadIndex];
    final dir = await _downloadsDir;
    final fileName =
        '${download.animeSlug}_ep${download.episodeNumber}_${download.serverType}.ts';
    final filePath = '${dir.path}/$fileName';

    try {
      // Check for m3u8/HLS streams
      if (url.contains('m3u8')) {
        logger.i(_tag, 'HLS stream detected, downloading segments: $url');
        await _downloadHlsStream(key, url, filePath);
        return;
      }

      // Direct video file download (for non-HLS streams)
      final cancelToken = CancelToken();
      _dioCancelTokens[key] = cancelToken;

      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final idx = downloads.indexWhere((d) => d.key == key);
            if (idx != -1) {
              downloads[idx] = downloads[idx].copyWith(
                progress: progress,
                fileSize: total,
              );
            }
          }
        },
      );

      // Mark as completed
      final file = File(filePath);
      final fileSize = await file.length();

      downloads[downloadIndex] = downloads[downloadIndex].copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: filePath,
        fileSize: fileSize,
      );
      await _saveDownloads();

      Get.snackbar(
        'Download Complete',
        'Episode ${download.episodeNumber} downloaded (${_formatFileSize(fileSize)})',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      _dioCancelTokens.remove(key);
    }
  }

  /// Get headers for HLS requests
  Map<String, String> _getHlsHeaders(String url) {
    final baseUrl = _apiService.baseUrl;
    return {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': baseUrl,
      'Origin': baseUrl,
    };
  }

  /// Download HLS stream by fetching playlist and downloading all segments
  Future<void> _downloadHlsStream(
    String key,
    String m3u8Url,
    String outputPath,
  ) async {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex == -1) return;

    final download = downloads[downloadIndex];
    final cancelToken = CancelToken();
    _dioCancelTokens[key] = cancelToken;

    try {
      logger.i(_tag, 'Fetching HLS playlist: $m3u8Url');

      // Fetch the m3u8 playlist with proper headers
      final response = await _dio.get(
        m3u8Url,
        cancelToken: cancelToken,
        options: Options(
          headers: _getHlsHeaders(m3u8Url),
        ),
      );

      if (_cancelTokens[key] == true) {
        _handleCancellation(key);
        return;
      }

      final playlistContent = response.data.toString();
      logger.d(_tag, 'Playlist content length: ${playlistContent.length}');

      // Parse the m3u8 playlist to get segment URLs
      final segments = _parseM3u8Playlist(playlistContent, m3u8Url);

      if (segments.isEmpty) {
        // This might be a master playlist, try to get the best quality stream
        final streamUrl = _extractBestQualityStream(playlistContent, m3u8Url);
        if (streamUrl != null) {
          logger.i(_tag, 'Found master playlist, fetching stream: $streamUrl');
          await _downloadHlsStream(key, streamUrl, outputPath);
          return;
        }
        throw Exception('No video segments found in playlist');
      }

      logger.i(_tag, 'Found ${segments.length} segments to download');

      // Create temp directory for segments
      final dir = await _downloadsDir;
      final tempDir = Directory('${dir.path}/temp_$key');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      // Download all segments
      var downloadedSize = 0;
      final segmentFiles = <File>[];

      for (var i = 0; i < segments.length; i++) {
        if (_cancelTokens[key] == true) {
          await tempDir.delete(recursive: true);
          _handleCancellation(key);
          return;
        }

        final segmentUrl = segments[i];
        final segmentFile = File(
          '${tempDir.path}/segment_${i.toString().padLeft(5, '0')}.ts',
        );

        try {
          final segmentResponse = await _dio.download(
            segmentUrl,
            segmentFile.path,
            cancelToken: cancelToken,
            options: Options(
              headers: _getHlsHeaders(segmentUrl),
            ),
          );

          segmentFiles.add(segmentFile);
          downloadedSize += await segmentFile.length();

          // Update progress
          final progress = (i + 1) / segments.length;
          final idx = downloads.indexWhere((d) => d.key == key);
          if (idx != -1) {
            downloads[idx] = downloads[idx].copyWith(
              progress: progress * 0.9, // Reserve 10% for merging
              fileSize: downloadedSize,
            );
          }

          logger.v(_tag, 'Downloaded segment ${i + 1}/${segments.length}');
        } catch (e) {
          logger.w(_tag, 'Failed to download segment $i: $e');
          // Continue with next segment
        }
      }

      if (segmentFiles.isEmpty) {
        await tempDir.delete(recursive: true);
        throw Exception('No segments were downloaded');
      }

      logger.i(_tag, 'Merging ${segmentFiles.length} segments...');

      // Merge all segments into one file
      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();

      for (final segmentFile in segmentFiles) {
        if (await segmentFile.exists()) {
          final bytes = await segmentFile.readAsBytes();
          sink.add(bytes);
        }
      }

      await sink.close();

      // Clean up temp directory
      await tempDir.delete(recursive: true);

      // Get final file size
      final finalSize = await outputFile.length();

      // Update download item
      final idx = downloads.indexWhere((d) => d.key == key);
      if (idx != -1) {
        downloads[idx] = downloads[idx].copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: outputPath,
          fileSize: finalSize,
        );
        await _saveDownloads();
      }

      Get.snackbar(
        'Download Complete',
        'Episode ${download.episodeNumber} downloaded (${_formatFileSize(finalSize)})',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );

      logger.i(
        _tag,
        'HLS download complete: $outputPath (${_formatFileSize(finalSize)})',
      );
    } catch (e) {
      logger.e(_tag, 'HLS download failed', error: e);

      // Clean up
      final file = File(outputPath);
      if (await file.exists()) await file.delete();

      rethrow;
    } finally {
      _dioCancelTokens.remove(key);
    }
  }

  /// Parse m3u8 playlist and extract segment URLs
  List<String> _parseM3u8Playlist(String content, String playlistUrl) {
    final segments = <String>[];
    final lines = content.split('\n');
    final baseUrl = _getBaseUrl(playlistUrl);

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Skip empty lines and comments/tags
      if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
        continue;
      }

      // This should be a segment URL
      String segmentUrl = trimmedLine;

      // Handle relative URLs
      if (!segmentUrl.startsWith('http')) {
        if (segmentUrl.startsWith('/')) {
          // Absolute path from domain root
          final uri = Uri.parse(playlistUrl);
          segmentUrl = '${uri.scheme}://${uri.host}$segmentUrl';
        } else {
          // Relative to playlist URL
          segmentUrl = '$baseUrl/$segmentUrl';
        }
      }

      segments.add(segmentUrl);
    }

    return segments;
  }

  /// Extract best quality stream URL from master playlist
  String? _extractBestQualityStream(String content, String playlistUrl) {
    final lines = content.split('\n');
    final baseUrl = _getBaseUrl(playlistUrl);

    String? bestStreamUrl;
    int bestBandwidth = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        // Extract bandwidth
        final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        final bandwidth = bandwidthMatch != null
            ? int.tryParse(bandwidthMatch.group(1) ?? '0') ?? 0
            : 0;

        // Get the stream URL (next non-empty, non-comment line)
        for (var j = i + 1; j < lines.length; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
            String streamUrl = nextLine;

            // Handle relative URLs
            if (!streamUrl.startsWith('http')) {
              if (streamUrl.startsWith('/')) {
                final uri = Uri.parse(playlistUrl);
                streamUrl = '${uri.scheme}://${uri.host}$streamUrl';
              } else {
                streamUrl = '$baseUrl/$streamUrl';
              }
            }

            if (bandwidth > bestBandwidth) {
              bestBandwidth = bandwidth;
              bestStreamUrl = streamUrl;
            }
            break;
          }
        }
      }
    }

    return bestStreamUrl;
  }

  /// Get base URL from a full URL (removes filename)
  String _getBaseUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments.toList();
    if (pathSegments.isNotEmpty) {
      pathSegments.removeLast();
    }
    return '${uri.scheme}://${uri.host}${pathSegments.isEmpty ? '' : '/${pathSegments.join('/')}'}';
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Handle download cancellation
  void _handleCancellation(String key) {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex != -1) {
      downloads[downloadIndex] = downloads[downloadIndex].copyWith(
        status: DownloadStatus.paused,
        errorMessage: 'Cancelled by user',
      );
      _saveDownloads();
    }
    activeDownloadKey.value = null;
    _cancelTokens.remove(key);
  }

  /// Cancel a download
  Future<void> cancelDownload(String key) async {
    _cancelTokens[key] = true;
    downloadQueue.remove(key);

    // Cancel Dio request if active
    final dioCancelToken = _dioCancelTokens[key];
    if (dioCancelToken != null && !dioCancelToken.isCancelled) {
      dioCancelToken.cancel('Cancelled by user');
    }

    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex != -1 &&
        downloads[downloadIndex].status != DownloadStatus.downloading) {
      downloads[downloadIndex] = downloads[downloadIndex].copyWith(
        status: DownloadStatus.paused,
        errorMessage: 'Cancelled by user',
      );
      await _saveDownloads();
    }
  }

  /// Delete a download
  Future<void> deleteDownload(String key) async {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex == -1) return;

    final download = downloads[downloadIndex];

    // Cancel if downloading
    _cancelTokens[key] = true;
    downloadQueue.remove(key);

    // Delete file if exists
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Remove from list
    downloads.removeAt(downloadIndex);
    await _saveDownloads();

    logger.logUserAction('Deleted download', details: {'key': key});
  }

  /// Delete all downloads for an anime
  Future<void> deleteAnimeDownloads(String animeSlug) async {
    final toDelete = downloads.where((d) => d.animeSlug == animeSlug).toList();

    for (final download in toDelete) {
      await deleteDownload(download.key);
    }
  }

  /// Retry a failed download
  Future<void> retryDownload(String key) async {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex == -1) return;

    downloads[downloadIndex] = downloads[downloadIndex].copyWith(
      status: DownloadStatus.pending,
      progress: 0.0,
      errorMessage: null,
    );
    await _saveDownloads();

    downloadQueue.add(key);
    _processDownloadQueue();
  }

  /// Get total download size
  int get totalDownloadSize {
    return downloads
        .where(
          (d) => d.status == DownloadStatus.completed && d.fileSize != null,
        )
        .fold(0, (sum, d) => sum + (d.fileSize ?? 0));
  }

  /// Get formatted total size
  String get totalDownloadSizeFormatted {
    final size = totalDownloadSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
