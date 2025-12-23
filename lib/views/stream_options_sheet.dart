import 'package:flutter/material.dart';
import '../models/response/anime_model.dart';
import '../models/response/episode_model.dart';
import '../utils/one_piece_theme.dart';
import 'video_player_screen.dart';

/// Shows a beautiful bottom sheet with streaming options
class StreamOptionsSheet extends StatefulWidget {
  final EpisodeModel episode;
  final AnimeModel? anime;
  final VoidCallback onOpenInBrowser;

  const StreamOptionsSheet({
    super.key,
    required this.episode,
    this.anime,
    required this.onOpenInBrowser,
  });

  static Future<void> show({
    required BuildContext context,
    required EpisodeModel episode,
    AnimeModel? anime,
    required VoidCallback onOpenInBrowser,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StreamOptionsSheet(
        episode: episode,
        anime: anime,
        onOpenInBrowser: onOpenInBrowser,
      ),
    );
  }

  @override
  State<StreamOptionsSheet> createState() => _StreamOptionsSheetState();
}

class _StreamOptionsSheetState extends State<StreamOptionsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  String _selectedType = 'sub';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _watchInApp() {
    Navigator.pop(context);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VideoPlayerScreen(
              episodeId: widget.episode.streamingId ?? widget.episode.id ?? '',
              episodeTitle: widget.episode.title,
              episodeNumber: widget.episode.number,
              animeThumbnail: widget.anime?.thumbnail,
              animeTitle: widget.anime?.title,
              serverType: _selectedType,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _watchInBrowser() {
    Navigator.pop(context);
    widget.onOpenInBrowser();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * _scaleAnimation.value),
          child: Opacity(opacity: _scaleAnimation.value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: OnePieceTheme.strawHatRed.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Episode Thumbnail/Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: OnePieceTheme.sunsetGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.episode.number ?? '?'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Episode Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.anime?.title ?? 'Unknown Anime',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.episode.title ??
                              'Episode ${widget.episode.number}',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.episode.isFiller == true)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FILLER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),

            // Server Type Selection
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT AUDIO',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAudioOption(
                          'SUB',
                          'sub',
                          Icons.subtitles,
                          'Japanese with Subtitles',
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAudioOption(
                          'DUB',
                          'dub',
                          Icons.mic,
                          'English Dubbed',
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Watch Options
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW TO WATCH',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Watch in App Option
                  _buildWatchOption(
                    icon: Icons.play_circle_filled,
                    title: 'Watch in App',
                    subtitle: 'Built-in player with skip intro/outro',
                    gradient: OnePieceTheme.sunsetGradient,
                    onTap: _watchInApp,
                    isPrimary: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Watch in Browser Option
                  _buildWatchOption(
                    icon: Icons.open_in_browser,
                    title: 'Open in Browser',
                    subtitle: 'Watch on the original website',
                    gradient: OnePieceTheme.oceanGradient,
                    onTap: _watchInBrowser,
                    isPrimary: false,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioOption(
    String label,
    String type,
    IconData icon,
    String description,
    bool isDark,
  ) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? OnePieceTheme.strawHatRed.withOpacity(0.15)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? OnePieceTheme.strawHatRed : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? OnePieceTheme.strawHatRed
                    : (isDark ? Colors.white10 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.black45),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? OnePieceTheme.strawHatRed
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: OnePieceTheme.strawHatRed,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
    required bool isPrimary,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isPrimary ? gradient : null,
            color: isPrimary
                ? null
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(16),
            border: isPrimary
                ? Border.all(
                    color: OnePieceTheme.strawHatGold.withOpacity(0.5),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withOpacity(0.2)
                      : (isDark ? Colors.white10 : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isPrimary ? Colors.white : OnePieceTheme.grandLineBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isPrimary
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isPrimary
                            ? Colors.white70
                            : (isDark ? Colors.white54 : Colors.black45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isPrimary
                    ? Colors.white70
                    : (isDark ? Colors.white38 : Colors.black26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
