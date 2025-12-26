import 'package:flutter/material.dart';
import '../../models/response/episode_model.dart';
import '../../utils/one_piece_theme.dart';

/// A widget that displays episodes in a grid with range selector
/// Similar to Hianime's episode list UI
class EpisodeGridWidget extends StatefulWidget {
  final List<EpisodeModel> episodes;
  final Function(EpisodeModel) onEpisodeTap;
  final Function(EpisodeModel)? onEpisodeLongPress;
  final int? lastWatchedEpisode;
  final int episodesPerRange;

  const EpisodeGridWidget({
    super.key,
    required this.episodes,
    required this.onEpisodeTap,
    this.onEpisodeLongPress,
    this.lastWatchedEpisode,
    this.episodesPerRange = 50,
  });

  @override
  State<EpisodeGridWidget> createState() => _EpisodeGridWidgetState();
}

class _EpisodeGridWidgetState extends State<EpisodeGridWidget> {
  int _selectedRangeIndex = 0;
  bool _isGridView = true;

  List<_EpisodeRange> get _ranges {
    final ranges = <_EpisodeRange>[];
    final totalEpisodes = widget.episodes.length;

    if (totalEpisodes <= widget.episodesPerRange) {
      // Single range for small anime
      ranges.add(
        _EpisodeRange(start: 1, end: totalEpisodes, label: '1-$totalEpisodes'),
      );
    } else {
      // Multiple ranges
      for (int i = 0; i < totalEpisodes; i += widget.episodesPerRange) {
        final start = i + 1;
        final end = (i + widget.episodesPerRange).clamp(1, totalEpisodes);
        ranges.add(_EpisodeRange(start: start, end: end, label: '$start-$end'));
      }
    }
    return ranges;
  }

  List<EpisodeModel> get _currentRangeEpisodes {
    if (_ranges.isEmpty) return widget.episodes;

    final range = _ranges[_selectedRangeIndex];
    return widget.episodes
        .where(
          (ep) =>
              (ep.number ?? 0) >= range.start && (ep.number ?? 0) <= range.end,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Auto-select range containing last watched episode
    if (widget.lastWatchedEpisode != null) {
      for (int i = 0; i < _ranges.length; i++) {
        if (widget.lastWatchedEpisode! >= _ranges[i].start &&
            widget.lastWatchedEpisode! <= _ranges[i].end) {
          _selectedRangeIndex = i;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with episode count and view toggle
        _buildHeader(),

        // Range selector (only show if multiple ranges)
        if (_ranges.length > 1) _buildRangeSelector(),

        const SizedBox(height: 12),

        // Episode grid/list
        _isGridView ? _buildEpisodeGrid() : _buildEpisodeList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Episodes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${widget.episodes.length} episodes available',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          Row(
            children: [
              // Grid view toggle
              IconButton(
                icon: Icon(
                  Icons.grid_view_rounded,
                  color: _isGridView ? OnePieceTheme.strawHatRed : Colors.grey,
                ),
                onPressed: () => setState(() => _isGridView = true),
                tooltip: 'Grid View',
              ),
              // List view toggle
              IconButton(
                icon: Icon(
                  Icons.list_rounded,
                  color: !_isGridView ? OnePieceTheme.strawHatRed : Colors.grey,
                ),
                onPressed: () => setState(() => _isGridView = false),
                tooltip: 'List View',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _ranges.length,
        itemBuilder: (context, index) {
          final range = _ranges[index];
          final isSelected = index == _selectedRangeIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedRangeIndex = index),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? OnePieceTheme.strawHatRed
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? OnePieceTheme.strawHatRed
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      range.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[300],
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeGrid() {
    final episodes = _currentRangeEpisodes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1.3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: episodes.length,
        itemBuilder: (context, index) {
          final episode = episodes[index];
          final episodeNumber = episode.number ?? (index + 1);
          final isWatched =
              widget.lastWatchedEpisode != null &&
              episodeNumber <= widget.lastWatchedEpisode!;
          final isLastWatched = widget.lastWatchedEpisode == episodeNumber;
          final isFiller = episode.isFiller == true;

          return _EpisodeGridTile(
            episodeNumber: episodeNumber,
            isWatched: isWatched,
            isLastWatched: isLastWatched,
            isFiller: isFiller,
            onTap: () => widget.onEpisodeTap(episode),
            onLongPress: widget.onEpisodeLongPress != null
                ? () => widget.onEpisodeLongPress!(episode)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEpisodeList() {
    final episodes = _currentRangeEpisodes;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final episodeNumber = episode.number ?? (index + 1);
        final isWatched =
            widget.lastWatchedEpisode != null &&
            episodeNumber <= widget.lastWatchedEpisode!;
        final isLastWatched = widget.lastWatchedEpisode == episodeNumber;
        final isFiller = episode.isFiller == true;

        return _EpisodeListTile(
          episode: episode,
          isWatched: isWatched,
          isLastWatched: isLastWatched,
          isFiller: isFiller,
          onTap: () => widget.onEpisodeTap(episode),
          onLongPress: widget.onEpisodeLongPress != null
              ? () => widget.onEpisodeLongPress!(episode)
              : null,
        );
      },
    );
  }
}

class _EpisodeRange {
  final int start;
  final int end;
  final String label;

  _EpisodeRange({required this.start, required this.end, required this.label});
}

class _EpisodeGridTile extends StatelessWidget {
  final int episodeNumber;
  final bool isWatched;
  final bool isLastWatched;
  final bool isFiller;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _EpisodeGridTile({
    required this.episodeNumber,
    required this.isWatched,
    required this.isLastWatched,
    required this.isFiller,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (isLastWatched) {
      backgroundColor = OnePieceTheme.strawHatRed;
      textColor = Colors.white;
      borderColor = OnePieceTheme.strawHatRed;
    } else if (isWatched) {
      backgroundColor = Colors.grey.withOpacity(0.3);
      textColor = Colors.grey;
      borderColor = Colors.grey.withOpacity(0.5);
    } else if (isFiller) {
      backgroundColor = Colors.orange.withOpacity(0.2);
      textColor = Colors.orange;
      borderColor = Colors.orange.withOpacity(0.5);
    } else {
      backgroundColor = Colors.grey.withOpacity(0.15);
      textColor = Colors.white;
      borderColor = Colors.grey.withOpacity(0.3);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$episodeNumber',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isLastWatched)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.play_arrow,
                    size: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              if (isFiller && !isWatched)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'F',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeListTile extends StatelessWidget {
  final EpisodeModel episode;
  final bool isWatched;
  final bool isLastWatched;
  final bool isFiller;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _EpisodeListTile({
    required this.episode,
    required this.isWatched,
    required this.isLastWatched,
    required this.isFiller,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isLastWatched ? OnePieceTheme.strawHatRed.withOpacity(0.15) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLastWatched
              ? OnePieceTheme.strawHatRed
              : isFiller
              ? Colors.orange
              : isWatched
              ? Colors.grey
              : Theme.of(context).colorScheme.primary,
          child: Text(
            '${episode.number ?? '?'}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          episode.title ?? 'Episode ${episode.number}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isWatched && !isLastWatched ? Colors.grey : null,
            fontWeight: isLastWatched ? FontWeight.bold : null,
          ),
        ),
        subtitle: episode.japaneseTitle != null
            ? Text(
                episode.japaneseTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isWatched ? Colors.grey : Colors.grey[400],
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFiller)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Filler',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isLastWatched)
              const Icon(
                Icons.play_circle_filled,
                color: OnePieceTheme.strawHatRed,
              ),
            if (!isLastWatched)
              Icon(
                isWatched ? Icons.check_circle : Icons.play_circle_outline,
                color: isWatched ? Colors.grey : Colors.white70,
              ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
