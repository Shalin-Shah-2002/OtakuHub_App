import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../utils/logger_service.dart';
import '../utils/one_piece_theme.dart';
import 'home_screen.dart';
import 'trending_screen.dart';
import 'search_screen.dart';
import 'watchlist_screen.dart';
import 'about_screen.dart';
import 'debug_log_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final StorageService storageService = Get.find<StorageService>();

  final List<Widget> _screens = const [
    HomeScreen(),
    TrendingScreen(),
    SearchScreen(),
    WatchlistScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Straw Hat icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: OnePieceTheme.strawHatGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: OnePieceTheme.strawHatGold.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.anchor,
                      color: OnePieceTheme.jollyRogerBlack,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'OtakuHub',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          // About button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Get.to(
              () => const AboutScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 300),
            ),
            tooltip: 'About',
          ),
          // Debug button (only in debug mode)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () => Get.to(() => const DebugLogScreen()),
              tooltip: 'View logs',
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: SafeArea(child: _screens[_currentIndex]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        animationDuration: const Duration(milliseconds: 400),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          logger.logNavigation(_getTitle(), _getTitleForIndex(index));
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Hot',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Obx(
              () => Badge(
                isLabelVisible: storageService.watchlist.isNotEmpty,
                label: Text('${storageService.watchlist.length}'),
                backgroundColor: OnePieceTheme.strawHatRed,
                child: const Icon(Icons.bookmark_outline),
              ),
            ),
            selectedIcon: Obx(
              () => Badge(
                isLabelVisible: storageService.watchlist.isNotEmpty,
                label: Text('${storageService.watchlist.length}'),
                backgroundColor: OnePieceTheme.strawHatRed,
                child: const Icon(Icons.bookmark),
              ),
            ),
            label: 'Crew',
          ),
        ],
      ),
    );
  }

  String _getTitle() => _getTitleForIndex(_currentIndex);

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Popular Anime';
      case 1:
        return 'Trending Anime';
      case 2:
        return 'Search Anime';
      case 3:
        return 'My Library';
      default:
        return 'Anime App';
    }
  }
}
