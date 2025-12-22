import 'package:get/get.dart';
import '../models/request/search_anime_request.dart';
import '../models/request/get_episodes_request.dart';
import '../models/response/anime_model.dart';
import '../models/response/episode_model.dart';
import '../services/api_service.dart';
import '../utils/logger_service.dart';

class AnimeController extends GetxController {
  static const String _tag = 'AnimeController';

  final ApiService _apiService;

  AnimeController({ApiService? apiService})
    : _apiService = apiService ?? ApiService() {
    logger.i(_tag, 'AnimeController initialized');
  }

  // State variables - using GetX reactive programming
  final RxList<AnimeModel> animeList = <AnimeModel>[].obs;
  final RxList<EpisodeModel> episodes = <EpisodeModel>[].obs;
  final Rx<AnimeModel?> selectedAnime = Rx<AnimeModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isLoadingEpisodes = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentPage = 1.obs;
  final RxBool hasNextPage = false.obs;

  @override
  void onInit() {
    super.onInit();
    logger.d(_tag, 'onInit called');

    // Log state changes
    ever(
      isLoading,
      (value) => logger.logStateChange(_tag, 'isLoading', value: value),
    );
    ever(errorMessage, (value) {
      if (value.isNotEmpty) {
        logger.logStateChange(_tag, 'errorMessage', value: value);
      }
    });
    ever(
      animeList,
      (value) =>
          logger.logStateChange(_tag, 'animeList.length', value: value.length),
    );
  }

  // Search anime
  Future<void> searchAnime(String keyword, {bool loadMore = false}) async {
    logger.logUserAction(
      'Search anime',
      details: {'keyword': keyword, 'loadMore': loadMore},
    );

    if (loadMore) {
      if (isLoading.value) {
        logger.d(_tag, 'Search skipped - already loading');
        return;
      }
      currentPage.value++;
    } else {
      currentPage.value = 1;
      animeList.clear();
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      logger.startTimer('searchAnime');

      final request = SearchAnimeRequest(
        keyword: keyword,
        page: currentPage.value,
      );

      final response = await _apiService.searchAnime(request);

      if (response.data != null) {
        animeList.addAll(response.data!);
        logger.i(
          _tag,
          'Search completed: found ${response.data!.length} results',
        );
      } else {
        logger.w(_tag, 'Search returned null data');
      }

      hasNextPage.value = (response.data?.length ?? 0) > 0;
      errorMessage.value = '';

      logger.stopTimer('searchAnime');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Search anime failed',
        error: e,
        stackTrace: stackTrace,
        extras: {'keyword': keyword, 'page': currentPage.value},
      );
      errorMessage.value = _formatErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  // Get popular anime
  Future<void> getPopularAnime({bool loadMore = false}) async {
    logger.logUserAction('Get popular anime', details: {'loadMore': loadMore});

    if (loadMore) {
      if (isLoading.value) {
        logger.d(_tag, 'Load more skipped - already loading');
        return;
      }
      currentPage.value++;
    } else {
      currentPage.value = 1;
      animeList.clear();
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      logger.startTimer('getPopularAnime');

      final response = await _apiService.getPopularAnime(
        page: currentPage.value,
      );

      if (response.data != null) {
        animeList.addAll(response.data!);
        logger.i(
          _tag,
          'Popular anime loaded: ${response.data!.length} items, total: ${animeList.length}',
        );
      } else {
        logger.w(_tag, 'Popular anime returned null data');
      }

      hasNextPage.value = (response.data?.length ?? 0) > 0;
      errorMessage.value = '';

      logger.stopTimer('getPopularAnime');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Get popular anime failed',
        error: e,
        stackTrace: stackTrace,
        extras: {'page': currentPage.value},
      );
      errorMessage.value = _formatErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  // Get top airing anime (trending)
  Future<void> getTopAiring({bool loadMore = false}) async {
    logger.logUserAction(
      'Get top airing anime',
      details: {'loadMore': loadMore},
    );

    if (loadMore) {
      if (isLoading.value) {
        logger.d(_tag, 'Load more skipped - already loading');
        return;
      }
      currentPage.value++;
    } else {
      currentPage.value = 1;
      animeList.clear();
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      logger.startTimer('getTopAiring');

      final response = await _apiService.getTopAiring(page: currentPage.value);

      if (response.data != null) {
        animeList.addAll(response.data!);
        logger.i(
          _tag,
          'Top airing anime loaded: ${response.data!.length} items, total: ${animeList.length}',
        );
      } else {
        logger.w(_tag, 'Top airing anime returned null data');
      }

      hasNextPage.value = (response.data?.length ?? 0) > 0;
      errorMessage.value = '';

      logger.stopTimer('getTopAiring');
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Get top airing anime failed',
        error: e,
        stackTrace: stackTrace,
        extras: {'page': currentPage.value},
      );
      errorMessage.value = _formatErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  // Get anime details
  Future<void> getAnimeDetails(String slug) async {
    logger.logUserAction('Get anime details', details: {'slug': slug});

    isLoading.value = true;
    errorMessage.value = '';

    try {
      logger.startTimer('getAnimeDetails_$slug');

      selectedAnime.value = await _apiService.getAnimeBySlug(slug);

      logger.i(_tag, 'Anime details loaded: ${selectedAnime.value?.title}');
      logger.stopTimer('getAnimeDetails_$slug');

      errorMessage.value = '';
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Get anime details failed',
        error: e,
        stackTrace: stackTrace,
        extras: {'slug': slug},
      );
      errorMessage.value = _formatErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  // Get anime episodes
  Future<void> getAnimeEpisodes(String slug) async {
    logger.logUserAction('Get anime episodes', details: {'slug': slug});

    episodes.clear();
    isLoadingEpisodes.value = true;
    errorMessage.value = '';

    try {
      logger.startTimer('getAnimeEpisodes_$slug');

      final request = GetEpisodesRequest(slug: slug);
      final response = await _apiService.getAnimeEpisodes(request);

      if (response.data != null) {
        episodes.addAll(response.data!);
        logger.i(_tag, 'Episodes loaded: ${response.data!.length} episodes');
      } else {
        logger.w(_tag, 'Episodes returned null data');
      }

      logger.stopTimer('getAnimeEpisodes_$slug');
      errorMessage.value = '';
    } catch (e, stackTrace) {
      logger.e(
        _tag,
        'Get anime episodes failed',
        error: e,
        stackTrace: stackTrace,
        extras: {'slug': slug},
      );
      errorMessage.value = _formatErrorMessage(e);
    } finally {
      isLoadingEpisodes.value = false;
    }
  }

  // Clear search results
  void clearResults() {
    logger.d(_tag, 'Clearing all results');
    animeList.clear();
    episodes.clear();
    selectedAnime.value = null;
    currentPage.value = 1;
    hasNextPage.value = false;
    errorMessage.value = '';
  }

  /// Format error message for UI display
  String _formatErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    final errorStr = error.toString();
    // Remove "Exception: " prefix if present
    if (errorStr.startsWith('Exception: ')) {
      return errorStr.substring(11);
    }
    return errorStr;
  }

  @override
  void onClose() {
    logger.i(_tag, 'AnimeController closing');
    _apiService.dispose();
    super.onClose();
  }
}
