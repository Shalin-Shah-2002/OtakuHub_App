import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/response/anime_model.dart';
import '../../models/request/search_anime_request.dart';
import '../../services/api_service.dart';
import '../../utils/one_piece_theme.dart';
import '../anime_detail_screen.dart';

/// Widget to display related seasons and movies for an anime
/// Searches for related content based on the anime title
class RelatedAnimeWidget extends StatefulWidget {
  final AnimeModel anime;

  const RelatedAnimeWidget({super.key, required this.anime});

  @override
  State<RelatedAnimeWidget> createState() => _RelatedAnimeWidgetState();
}

class _RelatedAnimeWidgetState extends State<RelatedAnimeWidget> {
  final ApiService _apiService = ApiService();
  List<AnimeModel> _relatedAnime = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadRelatedAnime();
  }

  /// Extract base title without season numbers, part numbers, etc.
  String _extractBaseTitle(String title) {
    // Common patterns to remove
    final patterns = [
      RegExp(r'\s*Season\s*\d+', caseSensitive: false),
      RegExp(r'\s*Part\s*\d+', caseSensitive: false),
      RegExp(r'\s*S\d+', caseSensitive: false),
      RegExp(r'\s*\d+(st|nd|rd|th)\s+Season', caseSensitive: false),
      RegExp(r'\s*:\s*[^:]+$'), // Remove subtitle after colon
      RegExp(r'\s*-\s*[^-]+$'), // Remove subtitle after dash
      RegExp(r'\s*\([^)]+\)'), // Remove anything in parentheses
      RegExp(r'\s*\[[^\]]+\]'), // Remove anything in brackets
      RegExp(r'\s*Movie.*$', caseSensitive: false),
      RegExp(r'\s*OVA.*$', caseSensitive: false),
      RegExp(r'\s*Special.*$', caseSensitive: false),
      RegExp(r'\s*The\s+Final.*$', caseSensitive: false),
      RegExp(r'\s*Final\s+Season.*$', caseSensitive: false),
      RegExp(r'\s*II+$'), // Roman numerals
      RegExp(r'\s*\d+$'), // Trailing numbers
    ];

    String baseTitle = title;
    for (final pattern in patterns) {
      baseTitle = baseTitle.replaceAll(pattern, '');
    }

    return baseTitle.trim();
  }

  Future<void> _loadRelatedAnime() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final title = widget.anime.title ?? '';
      if (title.isEmpty) {
        setState(() {
          _isLoading = false;
          _relatedAnime = [];
        });
        return;
      }

      // Get the base title for searching
      final baseTitle = _extractBaseTitle(title);

      // Search for related anime
      final response = await _apiService.searchAnime(
        SearchAnimeRequest(keyword: baseTitle, page: 1),
      );

      if (response.data != null) {
        // Filter and sort results
        final currentSlug = widget.anime.slug ?? '';
        final related = response.data!
            .where(
              (anime) =>
                  anime.slug != currentSlug && // Exclude current anime
                  _isRelated(anime.title ?? '', title, baseTitle),
            )
            .toList();

        // Sort: TV series first, then movies, then OVAs, etc.
        related.sort((a, b) {
          final typeOrder = {
            'TV': 0,
            'Movie': 1,
            'OVA': 2,
            'ONA': 3,
            'Special': 4,
          };
          final aOrder = typeOrder[a.type] ?? 5;
          final bOrder = typeOrder[b.type] ?? 5;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);

          // Then sort by title to group seasons together
          return (a.title ?? '').compareTo(b.title ?? '');
        });

        setState(() {
          _relatedAnime = related;
          _isLoading = false;
        });
      } else {
        setState(() {
          _relatedAnime = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /// Check if an anime is related to the current one
  bool _isRelated(String otherTitle, String currentTitle, String baseTitle) {
    final otherLower = otherTitle.toLowerCase();
    final baseLower = baseTitle.toLowerCase();

    // Must contain the base title
    if (!otherLower.contains(baseLower) && baseLower.length > 3) {
      // Try partial match for longer titles
      final words = baseLower.split(' ').where((w) => w.length > 3).toList();
      if (words.length < 2) return false;

      int matchCount = 0;
      for (final word in words) {
        if (otherLower.contains(word)) matchCount++;
      }
      // Need at least 60% word match
      if (matchCount < words.length * 0.6) return false;
    }

    return true;
  }

  String _getTypeLabel(AnimeModel anime) {
    final type = anime.type ?? 'Unknown';
    final title = (anime.title ?? '').toLowerCase();

    // Try to determine if it's a specific season
    if (title.contains('season 2') || title.contains('2nd season')) {
      return 'Season 2';
    } else if (title.contains('season 3') || title.contains('3rd season')) {
      return 'Season 3';
    } else if (title.contains('season 4') || title.contains('4th season')) {
      return 'Season 4';
    } else if (title.contains('season 5') || title.contains('5th season')) {
      return 'Season 5';
    } else if (title.contains('final season') || title.contains('the final')) {
      return 'Final';
    } else if (title.contains('movie')) {
      return 'Movie';
    } else if (title.contains('ova')) {
      return 'OVA';
    } else if (title.contains('special')) {
      return 'Special';
    } else if (type == 'Movie') {
      return 'Movie';
    } else if (type == 'OVA') {
      return 'OVA';
    } else if (type == 'ONA') {
      return 'ONA';
    } else if (type == 'Special') {
      return 'Special';
    }

    return type;
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'movie':
        return Colors.amber;
      case 'ova':
        return Colors.purple;
      case 'ona':
        return Colors.teal;
      case 'special':
        return Colors.pink;
      case 'final':
        return OnePieceTheme.strawHatRed;
      default:
        if (type.startsWith('Season')) {
          return OnePieceTheme.grandLineBlue;
        }
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return const SizedBox.shrink();
    }

    if (_relatedAnime.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.movie_filter, size: 20),
              const SizedBox(width: 8),
              Text(
                'Related Seasons & Movies',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: OnePieceTheme.strawHatRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_relatedAnime.length}',
                  style: const TextStyle(
                    color: OnePieceTheme.strawHatRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _relatedAnime.length,
            itemBuilder: (context, index) {
              final anime = _relatedAnime[index];
              final typeLabel = _getTypeLabel(anime);
              final typeColor = _getTypeColor(typeLabel);

              return _RelatedAnimeCard(
                anime: anime,
                typeLabel: typeLabel,
                typeColor: typeColor,
                onTap: () {
                  // Navigate to anime detail
                  Get.to(
                    () => AnimeDetailScreen(slug: anime.slug ?? ''),
                    preventDuplicates: false,
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RelatedAnimeCard extends StatelessWidget {
  final AnimeModel anime;
  final String typeLabel;
  final Color typeColor;
  final VoidCallback onTap;

  const _RelatedAnimeCard({
    required this.anime,
    required this.typeLabel,
    required this.typeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: anime.thumbnail ?? '',
                        height: 140,
                        width: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 140,
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 140,
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    // Type badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Episode count badge
                    if (anime.episodesSub != null || anime.episodesDub != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${anime.episodesSub ?? anime.episodesDub ?? 0} EP',
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
                // Title
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      anime.title ?? 'Unknown',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
