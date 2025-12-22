import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/watch_history_item.dart';
import '../models/response/anime_model.dart';
import '../models/response/episode_model.dart';
import '../utils/logger_service.dart';

/// Service for managing watchlist and watch history
class StorageService extends GetxService {
  static const String _tag = 'StorageService';
  static const String _watchlistKey = 'watchlist';
  static const String _watchHistoryKey = 'watch_history';
  static const String _baseUrlKey = 'api_base_url';
  static const String _firstLaunchKey = 'first_launch_complete';
  static const String _defaultBaseUrl = 'https://hianime-api-b6ix.onrender.com';
  static const int _maxHistoryItems = 10;

  late SharedPreferences _prefs;

  // Reactive lists for UI updates
  final RxList<WatchlistItem> watchlist = <WatchlistItem>[].obs;
  final RxList<WatchHistoryItem> watchHistory = <WatchHistoryItem>[].obs;

  /// Initialize the service
  Future<StorageService> init() async {
    logger.i(_tag, 'Initializing StorageService');
    _prefs = await SharedPreferences.getInstance();
    await _loadWatchlist();
    await _loadWatchHistory();
    logger.i(
      _tag,
      'StorageService initialized - Watchlist: ${watchlist.length}, History: ${watchHistory.length}',
    );
    return this;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // WATCHLIST METHODS
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _loadWatchlist() async {
    try {
      final jsonList = _prefs.getStringList(_watchlistKey) ?? [];
      watchlist.value = jsonList
          .map((json) => WatchlistItem.fromJsonString(json))
          .toList();
      logger.d(_tag, 'Loaded ${watchlist.length} watchlist items');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Failed to load watchlist',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveWatchlist() async {
    try {
      final jsonList = watchlist.map((item) => item.toJsonString()).toList();
      await _prefs.setStringList(_watchlistKey, jsonList);
      logger.d(_tag, 'Saved ${watchlist.length} watchlist items');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Failed to save watchlist',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Add anime to watchlist
  Future<void> addToWatchlist(AnimeModel anime) async {
    if (isInWatchlist(anime.slug ?? '')) {
      logger.d(_tag, 'Anime already in watchlist: ${anime.title}');
      return;
    }

    final item = WatchlistItem(
      slug: anime.slug ?? '',
      title: anime.title ?? 'Unknown',
      thumbnail: anime.thumbnail,
      type: anime.type,
      malScore: anime.malScore,
      episodesSub: anime.episodesSub,
      addedAt: DateTime.now(),
    );

    watchlist.insert(0, item);
    await _saveWatchlist();

    logger.logUserAction(
      'Added to watchlist',
      details: {'slug': anime.slug, 'title': anime.title},
    );

    Get.snackbar(
      'Added to Watchlist',
      '${anime.title} has been added to your watchlist',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// Remove anime from watchlist
  Future<void> removeFromWatchlist(String slug) async {
    final index = watchlist.indexWhere((item) => item.slug == slug);
    if (index != -1) {
      final removed = watchlist.removeAt(index);
      await _saveWatchlist();

      logger.logUserAction(
        'Removed from watchlist',
        details: {'slug': slug, 'title': removed.title},
      );

      Get.snackbar(
        'Removed from Watchlist',
        '${removed.title} has been removed',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Check if anime is in watchlist
  bool isInWatchlist(String slug) {
    return watchlist.any((item) => item.slug == slug);
  }

  /// Toggle watchlist status
  Future<void> toggleWatchlist(AnimeModel anime) async {
    if (isInWatchlist(anime.slug ?? '')) {
      await removeFromWatchlist(anime.slug ?? '');
    } else {
      await addToWatchlist(anime);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // WATCH HISTORY METHODS
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _loadWatchHistory() async {
    try {
      final jsonList = _prefs.getStringList(_watchHistoryKey) ?? [];
      watchHistory.value = jsonList
          .map((json) => WatchHistoryItem.fromJsonString(json))
          .toList();
      logger.d(_tag, 'Loaded ${watchHistory.length} watch history items');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Failed to load watch history',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveWatchHistory() async {
    try {
      final jsonList = watchHistory.map((item) => item.toJsonString()).toList();
      await _prefs.setStringList(_watchHistoryKey, jsonList);
      logger.d(_tag, 'Saved ${watchHistory.length} watch history items');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Failed to save watch history',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Add episode to watch history and open URL
  Future<void> playEpisode({
    required AnimeModel anime,
    required EpisodeModel episode,
  }) async {
    final url = episode.url;

    if (url == null || url.isEmpty) {
      logger.w(_tag, 'Episode URL is empty');
      Get.snackbar(
        'Error',
        'Episode URL not available',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Create history item
    final historyItem = WatchHistoryItem(
      animeSlug: anime.slug ?? '',
      animeTitle: anime.title ?? 'Unknown',
      animeThumbnail: anime.thumbnail,
      episodeNumber: episode.number ?? 0,
      episodeTitle: episode.title,
      episodeUrl: url,
      watchedAt: DateTime.now(),
    );

    // Remove existing entry for same episode (if any)
    watchHistory.removeWhere((item) => item.uniqueKey == historyItem.uniqueKey);

    // Add to beginning
    watchHistory.insert(0, historyItem);

    // Keep only last 10 items
    if (watchHistory.length > _maxHistoryItems) {
      watchHistory.removeRange(_maxHistoryItems, watchHistory.length);
    }

    await _saveWatchHistory();

    logger.logUserAction(
      'Playing episode',
      details: {'anime': anime.title, 'episode': episode.number, 'url': url},
    );

    // Open URL in browser
    await _launchUrl(url);
  }

  /// Open URL in browser
  Future<void> _launchUrl(String url) async {
    logger.i(_tag, 'Launching URL: $url');

    try {
      final uri = Uri.parse(url);

      // Try to launch URL directly - canLaunchUrl is unreliable on Android
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        logger.i(_tag, 'URL launched successfully');
      } else {
        logger.e(_tag, 'Cannot launch URL: $url');
        Get.snackbar(
          'Error',
          'Cannot open this URL. Please check if you have a browser installed.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e, stackTrace) {
      logger.e(_tag, 'Failed to launch URL', error: e, stackTrace: stackTrace);
      Get.snackbar(
        'Error',
        'Failed to open URL: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Open URL directly (for history items)
  Future<void> openUrl(String url) async {
    await _launchUrl(url);
  }

  /// Clear watch history
  Future<void> clearWatchHistory() async {
    watchHistory.clear();
    await _saveWatchHistory();
    logger.logUserAction('Cleared watch history');

    Get.snackbar(
      'History Cleared',
      'Watch history has been cleared',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Clear watchlist
  Future<void> clearWatchlist() async {
    watchlist.clear();
    await _saveWatchlist();
    logger.logUserAction('Cleared watchlist');

    Get.snackbar(
      'Watchlist Cleared',
      'Watchlist has been cleared',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Get last watched episode for an anime
  WatchHistoryItem? getLastWatchedEpisode(String animeSlug) {
    try {
      return watchHistory.firstWhere((item) => item.animeSlug == animeSlug);
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BASE URL CONFIGURATION METHODS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get the current base URL
  String? getBaseUrl() {
    return _prefs.getString(_baseUrlKey);
  }

  /// Get base URL or default
  String getBaseUrlOrDefault() {
    return _prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  /// Set the base URL
  Future<void> setBaseUrl(String url) async {
    // Remove trailing slash if present
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await _prefs.setString(_baseUrlKey, cleanUrl);
    logger.i(_tag, 'Base URL updated to: $cleanUrl');
  }

  /// Check if this is the first launch
  bool isFirstLaunch() {
    return !_prefs.containsKey(_firstLaunchKey) ||
        !(_prefs.getBool(_firstLaunchKey) ?? false);
  }

  /// Mark first launch as complete
  Future<void> setFirstLaunchComplete() async {
    await _prefs.setBool(_firstLaunchKey, true);
    logger.i(_tag, 'First launch marked as complete');
  }

  /// Test API connection
  Future<bool> testApiConnection(String baseUrl) async {
    try {
      final cleanUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      // Use /api/popular endpoint which we know exists
      final testUrl = '$cleanUrl/api/popular?page=1';

      logger.i(_tag, 'Testing API connection: $testUrl');

      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 15));

      logger.i(_tag, 'API test response: ${response.statusCode}');

      // Accept 200 as success
      return response.statusCode == 200;
    } catch (e) {
      logger.e(_tag, 'API connection test failed', error: e);
      return false;
    }
  }

  /// Get default base URL
  String get defaultBaseUrl => _defaultBaseUrl;
}
