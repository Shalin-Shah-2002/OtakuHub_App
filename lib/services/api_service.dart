import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/request/search_anime_request.dart';
import '../models/request/get_episodes_request.dart';
import '../models/response/anime_list_response.dart';
import '../models/response/episode_list_response.dart';
import '../models/response/anime_model.dart';
import '../utils/logger_service.dart';
import 'storage_service.dart';

class ApiService {
  static const String _tag = 'ApiService';

  // Default Base URL for HiAnime Scraper API (fallback)
  static const String defaultBaseUrl = 'https://hianime-api-b6ix.onrender.com';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client() {
    logger.i(_tag, 'ApiService initialized');
  }

  /// Get the current base URL from storage or use default
  String get baseUrl {
    try {
      final storageService = Get.find<StorageService>();
      return storageService.getBaseUrlOrDefault();
    } catch (e) {
      logger.w(_tag, 'StorageService not found, using default URL');
      return defaultBaseUrl;
    }
  }

  /// Generic API call wrapper with comprehensive logging
  Future<T> _executeRequest<T>({
    required String method,
    required Uri uri,
    required T Function(Map<String, dynamic> json) parser,
    String? bodyKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    logger.logApiRequest(method: method, url: uri.toString());

    try {
      final response = await _client.get(uri);
      stopwatch.stop();

      logger.logApiResponse(
        method: method,
        url: uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      if (response.statusCode == 200) {
        logger.v(_tag, 'Response body length: ${response.body.length} bytes');

        final json = jsonDecode(response.body);

        // Log successful parse
        logger.d(_tag, 'Successfully parsed JSON response');

        if (bodyKey != null && json[bodyKey] != null) {
          return parser(json[bodyKey]);
        }
        return parser(json);
      } else {
        final errorMsg =
            'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        logger.e(
          _tag,
          'API request failed',
          error: errorMsg,
          extras: {
            'url': uri.toString(),
            'statusCode': response.statusCode,
            'responseBody': response.body.length > 500
                ? '${response.body.substring(0, 500)}...'
                : response.body,
          },
        );
        throw ApiException(errorMsg, response.statusCode);
      }
    } on FormatException catch (e, stackTrace) {
      stopwatch.stop();
      logger.logApiError(
        method: method,
        url: uri.toString(),
        error: 'JSON Parse Error: $e',
        stackTrace: stackTrace,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw ApiException('Failed to parse response: $e', null);
    } on http.ClientException catch (e, stackTrace) {
      stopwatch.stop();
      logger.logApiError(
        method: method,
        url: uri.toString(),
        error: 'Network Error: $e',
        stackTrace: stackTrace,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw ApiException('Network error: $e', null);
    } catch (e, stackTrace) {
      stopwatch.stop();
      logger.logApiError(
        method: method,
        url: uri.toString(),
        error: e,
        stackTrace: stackTrace,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  // Search anime
  Future<AnimeListResponse> searchAnime(SearchAnimeRequest request) async {
    logger.i(_tag, 'Searching anime with keyword: "${request.keyword}"');

    final uri = Uri.parse(
      '$baseUrl/api/search',
    ).replace(queryParameters: request.toQueryParams());

    return _executeRequest(
      method: 'GET',
      uri: uri,
      parser: (json) => AnimeListResponse.fromJson(json),
    );
  }

  // Get popular anime
  Future<AnimeListResponse> getPopularAnime({int page = 1}) async {
    logger.i(_tag, 'Getting popular anime, page: $page');

    final uri = Uri.parse(
      '$baseUrl/api/popular',
    ).replace(queryParameters: {'page': page.toString()});

    return _executeRequest(
      method: 'GET',
      uri: uri,
      parser: (json) => AnimeListResponse.fromJson(json),
    );
  }

  // Get anime by slug
  Future<AnimeModel> getAnimeBySlug(String slug) async {
    logger.i(_tag, 'Getting anime details for slug: "$slug"');

    final uri = Uri.parse('$baseUrl/api/anime/$slug');

    return _executeRequest(
      method: 'GET',
      uri: uri,
      parser: (json) => AnimeModel.fromJson(json),
      bodyKey: 'data',
    );
  }

  // Get anime episodes
  Future<EpisodeListResponse> getAnimeEpisodes(
    GetEpisodesRequest request,
  ) async {
    logger.i(_tag, 'Getting episodes for slug: "${request.slug}"');

    final uri = Uri.parse('$baseUrl/api/episodes/${request.slug}');

    return _executeRequest(
      method: 'GET',
      uri: uri,
      parser: (json) => EpisodeListResponse.fromJson(json),
    );
  }

  // Get top airing anime
  Future<AnimeListResponse> getTopAiring({int page = 1}) async {
    logger.i(_tag, 'Getting top airing anime, page: $page');

    final uri = Uri.parse(
      '$baseUrl/api/top-airing',
    ).replace(queryParameters: {'page': page.toString()});

    return _executeRequest(
      method: 'GET',
      uri: uri,
      parser: (json) => AnimeListResponse.fromJson(json),
    );
  }

  void dispose() {
    logger.i(_tag, 'ApiService disposed');
    _client.close();
  }
}

/// Custom API Exception for better error handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => statusCode != null
      ? 'ApiException [$statusCode]: $message'
      : 'ApiException: $message';
}
