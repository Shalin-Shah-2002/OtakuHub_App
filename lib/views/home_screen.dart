import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/anime_controller.dart';
import '../services/storage_service.dart';
import '../utils/logger_service.dart';
import '../utils/one_piece_theme.dart';
import 'anime_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final AnimeController controller = Get.find<AnimeController>();
  final StorageService storageService = Get.find<StorageService>();

  @override
  void initState() {
    super.initState();
    logger.logNavigation('null', 'HomeScreen');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.getPopularAnime();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        controller.getPopularAnime(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.animeList.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.errorMessage.value.isNotEmpty &&
          controller.animeList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: ${controller.errorMessage.value}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => controller.getPopularAnime(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Section header with One Piece styling
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OnePieceTheme.strawHatRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.explore,
                    color: OnePieceTheme.strawHatRed,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Discover Anime',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await controller.getPopularAnime(refresh: true);
              },
              color: OnePieceTheme.strawHatRed,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount:
                    controller.animeList.length +
                    (controller.isLoading.value ? 2 : 0),
                itemBuilder: (context, index) {
                if (index >= controller.animeList.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final anime = controller.animeList[index];
                return InkWell(
                  onTap: () {
                    Get.to(() => AnimeDetailScreen(slug: anime.slug ?? ''));
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Image.network(
                            anime.thumbnail ?? '',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 50),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                anime.title ?? 'Unknown',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.tv,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${anime.episodesSub ?? 0} eps${anime.type != null ? ' • ${anime.type}' : ''}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),
          ),
        ],
      );
    });
  }
}
