import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../utils/one_piece_theme.dart';
import 'media_kit_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadService = Get.find<DownloadService>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: OnePieceTheme.grandLineBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.download_done,
                color: OnePieceTheme.grandLineBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Downloads'),
          ],
        ),
        actions: [
          // Storage info
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  downloadService.totalDownloadSizeFormatted,
                  style: const TextStyle(
                    color: OnePieceTheme.strawHatGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (downloadService.downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Downloads Yet',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Download episodes to watch offline',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Group downloads by anime
        final animeGroups = <String, List<DownloadItem>>{};
        for (final download in downloadService.downloads) {
          animeGroups.putIfAbsent(download.animeSlug, () => []);
          animeGroups[download.animeSlug]!.add(download);
        }

        // Sort episodes within each anime
        for (final list in animeGroups.values) {
          list.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
        }

        return RefreshIndicator(
          onRefresh: () => downloadService.refreshDownloads(),
          color: OnePieceTheme.grandLineBlue,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: animeGroups.length,
            itemBuilder: (context, index) {
              final animeSlug = animeGroups.keys.elementAt(index);
              final episodes = animeGroups[animeSlug]!;
              final firstEpisode = episodes.first;
              final completedCount = episodes
                  .where((e) => e.status == DownloadStatus.completed)
                  .length;

              return _AnimeDownloadCard(
                animeSlug: animeSlug,
                animeTitle: firstEpisode.animeTitle,
                animeThumbnail: firstEpisode.animeThumbnail,
                episodes: episodes,
                completedCount: completedCount,
              );
            },
          ),
        );
      }),
    );
  }
}

class _AnimeDownloadCard extends StatefulWidget {
  final String animeSlug;
  final String animeTitle;
  final String? animeThumbnail;
  final List<DownloadItem> episodes;
  final int completedCount;

  const _AnimeDownloadCard({
    required this.animeSlug,
    required this.animeTitle,
    this.animeThumbnail,
    required this.episodes,
    required this.completedCount,
  });

  @override
  State<_AnimeDownloadCard> createState() => _AnimeDownloadCardState();
}

class _AnimeDownloadCardState extends State<_AnimeDownloadCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final downloadService = Get.find<DownloadService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Anime Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.animeThumbnail ?? '',
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.movie),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.animeTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.completedCount} episode${widget.completedCount != 1 ? 's' : ''} downloaded',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand/Collapse icon
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                  // Delete all button
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete_all') {
                        _showDeleteConfirmation(context, downloadService);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete_all',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete All'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Episodes List (Expandable)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                ...widget.episodes.map(
                  (episode) => _EpisodeDownloadTile(download: episode),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, DownloadService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Downloads?'),
        content: Text(
          'Delete all ${widget.episodes.length} downloaded episodes of "${widget.animeTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              service.deleteAnimeDownloads(widget.animeSlug);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

class _EpisodeDownloadTile extends StatelessWidget {
  final DownloadItem download;

  const _EpisodeDownloadTile({required this.download});

  @override
  Widget build(BuildContext context) {
    final downloadService = Get.find<DownloadService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildStatusIcon(),
      title: Text(
        'Episode ${download.episodeNumber}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (download.episodeTitle != null)
            Text(
              download.episodeTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Server type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: download.serverType == 'sub'
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  download.serverType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: download.serverType == 'sub'
                        ? Colors.blue
                        : Colors.purple,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // File size or progress
              if (download.status == DownloadStatus.downloading)
                Expanded(
                  child: LinearProgressIndicator(
                    value: download.progress,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(
                      OnePieceTheme.grandLineBlue,
                    ),
                  ),
                )
              else if (download.fileSize != null && download.fileSize! > 0)
                Text(
                  download.fileSizeFormatted,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: _buildTrailingAction(context, downloadService),
      onTap: download.status == DownloadStatus.completed
          ? () => _playDownload(context)
          : null,
    );
  }

  Widget _buildStatusIcon() {
    switch (download.status) {
      case DownloadStatus.completed:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          radius: 18,
          child: Icon(Icons.check, color: Colors.white, size: 20),
        );
      case DownloadStatus.downloading:
        return CircleAvatar(
          backgroundColor: OnePieceTheme.grandLineBlue.withOpacity(0.2),
          radius: 18,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: download.progress,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(
                OnePieceTheme.grandLineBlue,
              ),
            ),
          ),
        );
      case DownloadStatus.pending:
        return CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          radius: 18,
          child: const Icon(
            Icons.hourglass_empty,
            color: Colors.orange,
            size: 20,
          ),
        );
      case DownloadStatus.failed:
        return const CircleAvatar(
          backgroundColor: Colors.red,
          radius: 18,
          child: Icon(Icons.error, color: Colors.white, size: 20),
        );
      case DownloadStatus.paused:
        return CircleAvatar(
          backgroundColor: Colors.grey.withOpacity(0.2),
          radius: 18,
          child: const Icon(Icons.pause, color: Colors.grey, size: 20),
        );
    }
  }

  Widget _buildTrailingAction(BuildContext context, DownloadService service) {
    switch (download.status) {
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_filled, size: 32),
              color: OnePieceTheme.grandLineBlue,
              onPressed: () => _playDownload(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () => _showDeleteDialog(context, service),
            ),
          ],
        );
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.cancel),
          color: Colors.red,
          onPressed: () => service.cancelDownload(download.key),
        );
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.cancel),
          color: Colors.orange,
          onPressed: () => service.cancelDownload(download.key),
        );
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              color: OnePieceTheme.grandLineBlue,
              onPressed: () => service.retryDownload(download.key),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () => service.deleteDownload(download.key),
            ),
          ],
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              color: OnePieceTheme.grandLineBlue,
              onPressed: () => service.retryDownload(download.key),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () => service.deleteDownload(download.key),
            ),
          ],
        );
    }
  }

  void _playDownload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaKitPlayerScreen(
          episodeId: download.episodeId,
          episodeTitle: download.episodeTitle,
          episodeNumber: download.episodeNumber,
          animeThumbnail: download.animeThumbnail,
          animeTitle: download.animeTitle,
          serverType: download.serverType,
          offlineFilePath: download.filePath,
          offlineStreamUrl: download.streamUrl,
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, DownloadService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download?'),
        content: Text(
          'Delete Episode ${download.episodeNumber} of "${download.animeTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              service.deleteDownload(download.key);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
