import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import '../models/response/anime_model.dart';
import '../models/response/episode_model.dart';
import '../utils/logger_service.dart';
import 'api_service.dart';

/// Service for managing episode downloads with background support
class DownloadService extends GetxService {
  static const String _tag = 'DownloadService';
  static const String _downloadsKey = 'downloads';
  static const int _downloadNotificationId = 1001;
  static const String _downloadChannelId = 'download_channel';
  static const String _downloadChannelName = 'Downloads';

  late SharedPreferences _prefs;
  final ApiService _apiService = ApiService();

  // Notification plugin for background download notifications
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

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
    await _initNotifications();
    logger.i(
      _tag,
      'DownloadService initialized - Downloads: ${downloads.length}',
    );
    return this;
  }

  /// Initialize notifications for background downloads
  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      if (!kIsWeb && Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          _downloadChannelId,
          _downloadChannelName,
          description: 'Shows download progress',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );

        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      _notificationsInitialized = true;
      logger.i(_tag, 'Notifications initialized');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Failed to initialize notifications',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could open downloads screen
    logger.d(_tag, 'Notification tapped: ${response.payload}');
  }

  /// Show/update download progress notification
  Future<void> _showDownloadNotification({
    required String title,
    required String body,
    int progress = 0,
    int maxProgress = 100,
    bool indeterminate = false,
    bool ongoing = true,
  }) async {
    if (!_notificationsInitialized) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _downloadChannelId,
        _downloadChannelName,
        channelDescription: 'Shows download progress',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: ongoing,
        autoCancel: !ongoing,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        indeterminate: indeterminate,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.progress,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        _downloadNotificationId,
        title,
        body,
        details,
      );
    } catch (e) {
      logger.w(_tag, 'Failed to show notification: $e');
    }
  }

  /// Cancel download notification
  Future<void> _cancelDownloadNotification() async {
    if (!_notificationsInitialized) return;
    try {
      await _notificationsPlugin.cancel(_downloadNotificationId);
    } catch (e) {
      logger.w(_tag, 'Failed to cancel notification: $e');
    }
  }

  /// Show download complete notification
  Future<void> _showDownloadCompleteNotification(String episodeTitle) async {
    if (!_notificationsInitialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _downloadChannelId,
        _downloadChannelName,
        channelDescription: 'Shows download progress',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        _downloadNotificationId + 1, // Different ID for completion
        'Download Complete',
        episodeTitle,
        details,
      );
    } catch (e) {
      logger.w(_tag, 'Failed to show completion notification: $e');
    }
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

      // Use the new MP4 download endpoint - server handles HLS to MP4 conversion!
      final filename =
          '${download.animeSlug}_ep${download.episodeNumber}_${download.serverType}';
      final mp4Url = _apiService.getMp4DownloadUrl(
        episodeId: download.episodeId,
        serverType: download.serverType,
        filename: filename,
      );

      logger.i(_tag, 'Downloading MP4 from: $mp4Url');
      logger.i(
        _tag,
        '⚠️ Note: Download may take 1-5 minutes as server converts HLS to MP4',
      );

      if (_cancelTokens[key] == true) {
        _handleCancellation(key);
        return;
      }

      // Download the MP4 file directly
      await _downloadMp4File(key, mp4Url, filename);

      // After video download, fetch and download subtitles
      await _downloadSubtitlesForEpisode(
        key,
        download.episodeId,
        download.serverType,
        filename,
      );
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
        'Failed to download episode: ${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      activeDownloadKey.value = null;
      _cancelTokens.remove(key);
      _processDownloadQueue();
    }
  }

  // Dio instance for downloads
  final Dio _dio = Dio();

  // Active cancel tokens for Dio
  final Map<String, CancelToken> _dioCancelTokens = {};

  /// Download MP4 file directly from the new /api/download/mp4/ endpoint
  /// This is the RECOMMENDED method - server handles HLS to MP4 conversion
  Future<void> _downloadMp4File(
    String key,
    String mp4Url,
    String filename,
  ) async {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex == -1) return;

    final download = downloads[downloadIndex];
    final dir = await _downloadsDir;
    final filePath = '${dir.path}/$filename.mp4';

    final episodeTitle =
        '${download.animeTitle} - Episode ${download.episodeNumber}';

    final cancelToken = CancelToken();
    _dioCancelTokens[key] = cancelToken;

    // Show initial notification
    await _showDownloadNotification(
      title: 'Downloading...',
      body: episodeTitle,
      progress: 0,
      indeterminate: true,
    );

    try {
      logger.i(_tag, 'Starting MP4 download to: $filePath');

      // Configure Dio for large file download with longer timeout
      final downloadDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(
            minutes: 30,
          ), // MP4 conversion can take time
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      int lastNotificationUpdate = 0;

      await downloadDio.download(
        mp4Url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          // Server may not always send content-length for streamed response
          if (total > 0) {
            final progress = received / total;
            final idx = downloads.indexWhere((d) => d.key == key);
            if (idx != -1) {
              downloads[idx] = downloads[idx].copyWith(
                progress: progress,
                fileSize: total,
              );
            }

            // Update notification every 2% progress
            final progressPercent = (progress * 100).toInt();
            if (progressPercent > lastNotificationUpdate + 2) {
              lastNotificationUpdate = progressPercent;
              _showDownloadNotification(
                title: 'Downloading... $progressPercent%',
                body: episodeTitle,
                progress: progressPercent,
                maxProgress: 100,
              );
            }
          } else {
            // Unknown total size - show bytes downloaded
            final idx = downloads.indexWhere((d) => d.key == key);
            if (idx != -1) {
              downloads[idx] = downloads[idx].copyWith(fileSize: received);
            }

            // Update notification with size
            if (received - lastNotificationUpdate > 5 * 1024 * 1024) {
              lastNotificationUpdate = received;
              _showDownloadNotification(
                title: 'Downloading...',
                body: '$episodeTitle (${_formatFileSize(received)})',
                indeterminate: true,
              );
            }

            // Log progress periodically
            if (received % (5 * 1024 * 1024) < 100000) {
              // Every ~5MB
              logger.d(_tag, 'Downloaded ${_formatFileSize(received)}...');
            }
          }
        },
      );

      // Verify file was downloaded
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found');
      }

      final fileSize = await file.length();
      if (fileSize < 1000) {
        // File too small, likely an error response
        final content = await file.readAsString();
        await file.delete();
        throw Exception('Download failed: $content');
      }

      // Mark as completed (subtitles will be added separately)
      downloads[downloadIndex] = downloads[downloadIndex].copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: filePath,
        fileSize: fileSize,
      );
      await _saveDownloads();

      logger.i(_tag, '✅ Video download complete: ${_formatFileSize(fileSize)}');

      // Show completion notification
      await _cancelDownloadNotification();
      await _showDownloadCompleteNotification(episodeTitle);

      Get.snackbar(
        'Download Complete',
        'Episode downloaded (${_formatFileSize(fileSize)}). Downloading subtitles...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      logger.e(_tag, 'MP4 download failed', error: e);
      await _cancelDownloadNotification();
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      _dioCancelTokens.remove(key);
    }
  }

  /// Download all available subtitles for an episode
  Future<void> _downloadSubtitlesForEpisode(
    String key,
    String episodeId,
    String serverType,
    String baseFilename,
  ) async {
    try {
      logger.i(_tag, 'Fetching subtitles for episode: $episodeId');

      // Get stream data to find available subtitles
      final streamResponse = await _apiService.getStreamingLinks(
        episodeId: episodeId,
        serverType: serverType,
        includeProxy: true,
      );

      if (!streamResponse.success || streamResponse.streams.isEmpty) {
        logger.w(_tag, 'No stream data available for subtitles');
        return;
      }

      // Get subtitles from the first stream (they're usually the same across servers)
      final subtitles = streamResponse.streams.first.subtitles;

      if (subtitles.isEmpty) {
        logger.i(_tag, 'No subtitles available for this episode');
        return;
      }

      logger.i(_tag, 'Found ${subtitles.length} subtitle tracks to download');

      final dir = await _downloadsDir;
      final subtitleDir = Directory('${dir.path}/subtitles');
      if (!await subtitleDir.exists()) {
        await subtitleDir.create(recursive: true);
      }

      final downloadedSubtitles = <DownloadedSubtitle>[];

      for (var i = 0; i < subtitles.length; i++) {
        final subtitle = subtitles[i];

        if (subtitle.file.isEmpty) continue;

        try {
          // Create a clean filename for the subtitle
          final subtitleFilename =
              '${baseFilename}_${_sanitizeFilename(subtitle.label)}.vtt';
          final subtitlePath = '${subtitleDir.path}/$subtitleFilename';

          logger.d(
            _tag,
            'Downloading subtitle: ${subtitle.label} from ${subtitle.file}',
          );

          // Download the subtitle file
          final response = await _dio.get(
            subtitle.file,
            options: Options(
              responseType: ResponseType.plain,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://megacloud.tv/',
              },
            ),
          );

          if (response.statusCode == 200 && response.data != null) {
            final subtitleContent = response.data.toString();

            // Save the subtitle file
            final subtitleFile = File(subtitlePath);
            await subtitleFile.writeAsString(subtitleContent);

            // Extract language from label (e.g., "English" -> "en")
            final language = _extractLanguageCode(subtitle.label);

            downloadedSubtitles.add(
              DownloadedSubtitle(
                label: subtitle.label,
                language: language,
                filePath: subtitlePath,
              ),
            );

            logger.d(_tag, '✅ Downloaded subtitle: ${subtitle.label}');
          }
        } catch (e) {
          logger.w(_tag, 'Failed to download subtitle ${subtitle.label}: $e');
          // Continue with other subtitles even if one fails
        }
      }

      // Update the download item with subtitles
      if (downloadedSubtitles.isNotEmpty) {
        final downloadIndex = downloads.indexWhere((d) => d.key == key);
        if (downloadIndex != -1) {
          downloads[downloadIndex] = downloads[downloadIndex].copyWith(
            subtitles: downloadedSubtitles,
          );
          await _saveDownloads();

          logger.i(
            _tag,
            '✅ Downloaded ${downloadedSubtitles.length} subtitle tracks',
          );

          Get.snackbar(
            'Subtitles Downloaded',
            '${downloadedSubtitles.length} subtitle(s) available for offline viewing',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      logger.w(_tag, 'Failed to download subtitles: $e');
      // Don't throw - subtitles are optional, video is already downloaded
    }
  }

  /// Sanitize filename to remove invalid characters
  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// Extract language code from subtitle label
  String _extractLanguageCode(String label) {
    final labelLower = label.toLowerCase();

    // Common language mappings
    if (labelLower.contains('english')) return 'en';
    if (labelLower.contains('spanish') || labelLower.contains('español')) {
      return 'es';
    }
    if (labelLower.contains('french') || labelLower.contains('français')) {
      return 'fr';
    }
    if (labelLower.contains('german') || labelLower.contains('deutsch')) {
      return 'de';
    }
    if (labelLower.contains('portuguese') || labelLower.contains('português')) {
      return 'pt';
    }
    if (labelLower.contains('italian') || labelLower.contains('italiano')) {
      return 'it';
    }
    if (labelLower.contains('russian') || labelLower.contains('русский')) {
      return 'ru';
    }
    if (labelLower.contains('japanese') || labelLower.contains('日本語')) {
      return 'ja';
    }
    if (labelLower.contains('korean') || labelLower.contains('한국어')) {
      return 'ko';
    }
    if (labelLower.contains('chinese') || labelLower.contains('中文')) {
      return 'zh';
    }
    if (labelLower.contains('arabic') || labelLower.contains('العربية')) {
      return 'ar';
    }
    if (labelLower.contains('hindi') || labelLower.contains('हिन्दी')) {
      return 'hi';
    }
    if (labelLower.contains('indonesian')) return 'id';
    if (labelLower.contains('malay')) return 'ms';
    if (labelLower.contains('thai') || labelLower.contains('ไทย')) return 'th';
    if (labelLower.contains('vietnamese') ||
        labelLower.contains('tiếng việt')) {
      return 'vi';
    }
    if (labelLower.contains('turkish') || labelLower.contains('türkçe')) {
      return 'tr';
    }
    if (labelLower.contains('polish') || labelLower.contains('polski')) {
      return 'pl';
    }
    if (labelLower.contains('dutch') || labelLower.contains('nederlands')) {
      return 'nl';
    }

    return 'unknown';
  }

  /// Download video file (legacy method for HLS streams)
  /// Kept for fallback in case MP4 endpoint has issues
  // ignore: unused_element
  Future<void> _downloadVideo(
    String key,
    String url, {
    Map<String, String>? headers,
  }) async {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex == -1) return;

    final download = downloads[downloadIndex];
    final dir = await _downloadsDir;
    final fileName =
        '${download.animeSlug}_ep${download.episodeNumber}_${download.serverType}.ts';
    final filePath = '${dir.path}/$fileName';

    // Merge custom headers with default headers
    final requestHeaders = {
      ..._getHlsHeaders(url),
      if (headers != null) ...headers,
    };

    try {
      // Check for m3u8/HLS streams
      if (url.contains('m3u8')) {
        logger.i(_tag, 'HLS stream detected, downloading segments: $url');
        await _downloadHlsStream(key, url, filePath, customHeaders: headers);
        return;
      }

      // Direct video file download (for non-HLS streams)
      final cancelToken = CancelToken();
      _dioCancelTokens[key] = cancelToken;

      logger.i(_tag, 'Starting direct download: $url');

      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        options: Options(headers: requestHeaders),
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

  /// Get headers for HLS requests based on URL domain
  Map<String, String> _getHlsHeaders(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';

    // Different CDNs require different Referer headers
    // Based on STREAMING_API_IMPLEMENTATION.md documentation
    String referer = 'https://megacloud.blog/';
    String origin = 'https://megacloud.blog';

    // If URL is a proxy URL from our API, use the API as referer
    if (host.contains('hianime-api') ||
        host.contains('onrender.com') ||
        host.contains('localhost')) {
      final baseUrl = _apiService.baseUrl;
      referer = baseUrl;
      origin = baseUrl;
    }

    return {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': referer,
      'Origin': origin,
    };
  }

  /// Download HLS stream by fetching playlist and downloading all segments
  Future<void> _downloadHlsStream(
    String key,
    String m3u8Url,
    String outputPath, {
    Map<String, String>? customHeaders,
  }) async {
    final downloadIndex = downloads.indexWhere((d) => d.key == key);
    if (downloadIndex == -1) return;

    final download = downloads[downloadIndex];
    final cancelToken = CancelToken();
    _dioCancelTokens[key] = cancelToken;

    // Merge custom headers with default headers
    final requestHeaders = {
      ..._getHlsHeaders(m3u8Url),
      if (customHeaders != null) ...customHeaders,
    };

    try {
      logger.i(_tag, 'Fetching HLS playlist: $m3u8Url');

      // Fetch the m3u8 playlist with proper headers
      final response = await _dio.get(
        m3u8Url,
        cancelToken: cancelToken,
        options: Options(headers: requestHeaders),
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
          await _downloadHlsStream(
            key,
            streamUrl,
            outputPath,
            customHeaders: customHeaders,
          );
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

        // Merge custom headers with segment headers
        final segmentHeaders = {
          ..._getHlsHeaders(segmentUrl),
          if (customHeaders != null) ...customHeaders,
        };

        try {
          await _dio.download(
            segmentUrl,
            segmentFile.path,
            cancelToken: cancelToken,
            options: Options(headers: segmentHeaders),
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

    // Delete video file if exists
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Delete subtitle files if they exist
    for (final subtitle in download.subtitles) {
      try {
        final subtitleFile = File(subtitle.filePath);
        if (await subtitleFile.exists()) {
          await subtitleFile.delete();
        }
      } catch (e) {
        logger.w(_tag, 'Failed to delete subtitle file: ${subtitle.filePath}');
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

  /// Delete all downloads
  Future<void> deleteAllDownloads() async {
    // Cancel any active downloads first
    for (final key in _cancelTokens.keys) {
      _cancelTokens[key] = true;
    }
    downloadQueue.clear();

    // Delete all download files
    final toDelete = downloads.toList();
    for (final download in toDelete) {
      if (download.filePath != null) {
        final file = File(download.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    // Clear the downloads list
    downloads.clear();
    await _saveDownloads();

    // Clean up temp directories
    final dir = await _downloadsDir;
    final contents = dir.listSync();
    for (final entity in contents) {
      if (entity is Directory && entity.path.contains('temp_')) {
        await entity.delete(recursive: true);
      }
    }

    logger.logUserAction('Deleted all downloads');
  }

  /// Delete only completed downloads
  Future<void> deleteCompletedDownloads() async {
    final toDelete = downloads
        .where((d) => d.status == DownloadStatus.completed)
        .toList();

    for (final download in toDelete) {
      await deleteDownload(download.key);
    }

    logger.logUserAction(
      'Deleted completed downloads',
      details: {'count': toDelete.length},
    );
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
