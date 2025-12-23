import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/anime_controller.dart';
import '../models/response/episode_model.dart';
import '../services/storage_service.dart';
import '../utils/logger_service.dart';
import '../utils/one_piece_theme.dart';
import 'stream_options_sheet.dart';

class AnimeDetailScreen extends StatefulWidget {
  final String slug;

  const AnimeDetailScreen({super.key, required this.slug});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  final AnimeController controller = Get.find<AnimeController>();
  final StorageService storageService = Get.find<StorageService>();

  @override
  void initState() {
    super.initState();
    logger.logNavigation(
      'previous',
      'AnimeDetailScreen',
      params: {'slug': widget.slug},
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.getAnimeDetails(widget.slug);
      controller.getAnimeEpisodes(widget.slug);
    });
  }

  void _playEpisode(EpisodeModel episode) {
    final anime = controller.selectedAnime.value;
    if (anime == null) {
      Get.snackbar(
        'Error',
        'Anime details not loaded',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Show stream options sheet
    StreamOptionsSheet.show(
      context: context,
      episode: episode,
      anime: anime,
      onOpenInBrowser: () {
        // Add to history and open in browser (existing behavior)
        storageService.playEpisode(anime: anime, episode: episode);
      },
    );
  }

  void _showEpisodeLinkDialog(EpisodeModel episode) {
    if (episode.url == null || episode.url!.isEmpty) {
      Get.snackbar(
        'Error',
        'Episode URL not available',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(episode.title ?? 'Episode ${episode.number}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (episode.japaneseTitle != null) ...[
                Text(
                  episode.japaneseTitle!,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Episode Link:'),
              const SizedBox(height: 8),
              SelectableText(
                episode.url!,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              if (episode.isFiller == true) ...[
                const SizedBox(height: 16),
                const Chip(
                  label: Text('Filler Episode'),
                  backgroundColor: Colors.orange,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _playEpisode(episode);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.selectedAnime.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.selectedAnime.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${controller.errorMessage.value}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    controller.getAnimeDetails(widget.slug);
                    controller.getAnimeEpisodes(widget.slug);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final anime = controller.selectedAnime.value;
        if (anime == null) {
          return const Center(child: Text('Anime not found'));
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              actions: [
                // Watchlist button
                Obx(() {
                  final isInWatchlist = storageService.isInWatchlist(
                    anime.slug ?? '',
                  );
                  return IconButton(
                    icon: Icon(
                      isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                      color: isInWatchlist ? Colors.amber : null,
                    ),
                    onPressed: () => storageService.toggleWatchlist(anime),
                    tooltip: isInWatchlist
                        ? 'Remove from watchlist'
                        : 'Add to watchlist',
                  );
                }),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  anime.title ?? 'Unknown',
                  style: const TextStyle(
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 3.0,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
                background: Image.network(
                  anime.thumbnail ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Continue watching banner
                    Obx(() {
                      final lastWatched = storageService.getLastWatchedEpisode(
                        anime.slug ?? '',
                      );
                      if (lastWatched != null) {
                        return Card(
                          color: OnePieceTheme.strawHatRed.withOpacity(0.15),
                          child: ListTile(
                            leading: const Icon(
                              Icons.play_circle_filled,
                              size: 40,
                              color: OnePieceTheme.strawHatRed,
                            ),
                            title: const Text('Continue Watching'),
                            subtitle: Text(
                              'Episode ${lastWatched.episodeNumber}${lastWatched.episodeTitle != null ? ' - ${lastWatched.episodeTitle}' : ''}',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => storageService.openUrl(
                                lastWatched.episodeUrl,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OnePieceTheme.strawHatRed,
                              ),
                              child: const Text('Resume'),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(height: 8),

                    // Anime Info
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (anime.malScore != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                anime.malScore.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        if (anime.type != null) Chip(label: Text(anime.type!)),
                        if (anime.status != null)
                          Chip(label: Text(anime.status!)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Episodes info
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (anime.episodesSub != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.subtitles, size: 20),
                              const SizedBox(width: 4),
                              Text('${anime.episodesSub} Sub'),
                            ],
                          ),
                        if (anime.episodesDub != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mic, size: 20),
                              const SizedBox(width: 4),
                              Text('${anime.episodesDub} Dub'),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Genres
                    if (anime.genres != null && anime.genres!.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: anime.genres!
                            .map(
                              (genre) => Chip(
                                label: Text(
                                  genre,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: Colors.deepPurple,
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 16),

                    // Studios
                    if (anime.studios != null && anime.studios!.isNotEmpty) ...[
                      Text(
                        'Studios',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: anime.studios!
                            .map(
                              (studio) => Chip(
                                label: Text(
                                  studio,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.blueGrey,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Synopsis
                    if (anime.synopsis != null) ...[
                      Text(
                        'Synopsis',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        anime.synopsis!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Episodes Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Episodes',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${controller.episodes.length} episodes',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Episodes List
            if (controller.isLoadingEpisodes.value &&
                controller.episodes.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (controller.episodes.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No episodes available'),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final episode = controller.episodes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: episode.isFiller == true
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${episode.number ?? '?'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        episode.title ?? 'Episode ${episode.number}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: episode.japaneseTitle != null
                          ? Text(
                              episode.japaneseTitle!,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: SizedBox(
                        width: episode.isFiller == true ? 140 : 96,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (episode.isFiller == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Filler',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            // Play button
                            IconButton(
                              icon: Icon(
                                Icons.play_circle_filled,
                                color: Theme.of(context).colorScheme.primary,
                                size: 32,
                              ),
                              onPressed:
                                  episode.url != null && episode.url!.isNotEmpty
                                  ? () => _playEpisode(episode)
                                  : null,
                              tooltip: 'Play Episode',
                            ),
                            // Info button
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showEpisodeLinkDialog(episode),
                              tooltip: 'Episode Info',
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _showEpisodeLinkDialog(episode),
                    ),
                  );
                }, childCount: controller.episodes.length),
              ),
            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      }),
    );
  }
}
