import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../utils/logger_service.dart';
import '../utils/one_piece_theme.dart';
import 'anime_detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = Get.find<StorageService>();
    logger.logNavigation('previous', 'WatchlistScreen');

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // One Piece styled header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OnePieceTheme.strawHatRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.groups,
                    color: OnePieceTheme.strawHatRed,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'My Crew',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.bookmark), text: 'Watchlist'),
              Tab(icon: Icon(Icons.history), text: 'Watch History'),
            ],
            labelColor: OnePieceTheme.strawHatRed,
            indicatorColor: OnePieceTheme.strawHatRed,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _WatchlistTab(storageService: storageService),
                _WatchHistoryTab(storageService: storageService),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchlistTab extends StatelessWidget {
  final StorageService storageService;

  const _WatchlistTab({required this.storageService});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (storageService.watchlist.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Your watchlist is empty',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Add anime to your watchlist to see them here',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          // Trigger a refresh of the watchlist
          await storageService.refreshData();
        },
        color: OnePieceTheme.strawHatRed,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: storageService.watchlist.length,
          itemBuilder: (context, index) {
            final item = storageService.watchlist[index];
            return Dismissible(
            key: Key(item.slug),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => storageService.removeFromWatchlist(item.slug),
            child: Card(
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.thumbnail ?? '',
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 70,
                      color: Colors.grey[300],
                      child: const Icon(Icons.movie),
                    ),
                  ),
                ),
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (item.type != null) item.type,
                    if (item.malScore != null) '★ ${item.malScore}',
                    if (item.episodesSub != null) '${item.episodesSub} eps',
                  ].where((e) => e != null).join(' • '),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark_remove),
                  onPressed: () =>
                      storageService.removeFromWatchlist(item.slug),
                ),
                onTap: () => Get.to(() => AnimeDetailScreen(slug: item.slug)),
              ),
            ),
          );
        },
        ),
      );
    });
  }
}

class _WatchHistoryTab extends StatelessWidget {
  final StorageService storageService;

  const _WatchHistoryTab({required this.storageService});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (storageService.watchHistory.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No watch history',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Your last 10 watched episodes will appear here',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          // Trigger a refresh of the watch history
          await storageService.refreshData();
        },
        color: OnePieceTheme.strawHatRed,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: storageService.watchHistory.length,
          itemBuilder: (context, index) {
            final item = storageService.watchHistory[index];
            final timeAgo = _getTimeAgo(item.watchedAt);

          return Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
                      item.animeThumbnail ?? '',
                      width: 50,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50,
                        height: 70,
                        color: Colors.grey[300],
                        child: const Icon(Icons.movie),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'EP ${item.episodeNumber}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                item.animeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.episodeTitle ?? 'Episode ${item.episodeNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: SizedBox(
                width: 96,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Continue watching button
                    IconButton(
                      icon: const Icon(Icons.play_circle_filled),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () => storageService.openUrl(item.episodeUrl),
                      tooltip: 'Continue watching',
                    ),
                    // Go to anime
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () =>
                          Get.to(() => AnimeDetailScreen(slug: item.animeSlug)),
                      tooltip: 'View anime',
                    ),
                  ],
                ),
              ),
              onTap: () => storageService.openUrl(item.episodeUrl),
            ),
          );
        },
        ),
      );
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
