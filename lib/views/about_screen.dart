import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../utils/one_piece_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Animated App Bar with One Piece theme
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: OnePieceTheme.strawHatRed,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'About OtakuHub',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Animated ocean waves background
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: WavePainter(
                          waveAnimation: _waveController.value,
                          waveColor: OnePieceTheme.grandLineBlue,
                        ),
                      );
                    },
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          OnePieceTheme.strawHatRed.withOpacity(0.8),
                          OnePieceTheme.deepSea.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                  // Straw Hat Icon
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: OnePieceTheme.strawHatGold,
                                  boxShadow: [
                                    BoxShadow(
                                      color: OnePieceTheme.strawHatGold
                                          .withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.anchor,
                                  size: 60,
                                  color: OnePieceTheme.jollyRogerBlack,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Info Card
                    _buildAnimatedCard(
                      delay: 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF1A1A2E),
                                    const Color(0xFF16213E),
                                  ]
                                : [Colors.white, OnePieceTheme.parchment],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: OnePieceTheme.strawHatGold.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: OnePieceTheme.strawHatRed,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.sailing,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'OtakuHub',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: OnePieceTheme.strawHatRed,
                                            ),
                                      ),
                                      Text(
                                        'Version 1.0.0',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              '"I\'m gonna be King of the Pirates!" - Monkey D. Luffy',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                                color: isDark
                                    ? OnePieceTheme.strawHatGold
                                    : OnePieceTheme.grandLineBlue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'OtakuHub is your ultimate anime companion app, '
                              'designed for true nakama who share the love for anime! '
                              'Browse, discover, and track your favorite anime series.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Developer Info Section
                    _buildSectionTitle(context, '⚓ Captain (Developer)'),
                    const SizedBox(height: 12),
                    _buildAnimatedCard(
                      delay: 200,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF1A1A2E),
                                    const Color(0xFF16213E),
                                  ]
                                : [Colors.white, OnePieceTheme.parchment],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: OnePieceTheme.grandLineBlue.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Profile picture placeholder
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    OnePieceTheme.strawHatRed,
                                    OnePieceTheme.strawHatGold,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: OnePieceTheme.strawHatRed
                                        .withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Shalin Shah',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Flutter Developer & One Piece Fan',
                              style: TextStyle(
                                color: isDark
                                    ? OnePieceTheme.seaBlue
                                    : OnePieceTheme.grandLineBlue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Social Links
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialButton(
                                  icon: Icons.email,
                                  label: 'Email',
                                  onTap: () =>
                                      _launchUrl('mailto:2002shalin@gmail.com'),
                                ),
                                const SizedBox(width: 12),
                                _buildSocialButton(
                                  icon: Icons.code,
                                  label: 'GitHub',
                                  onTap: () => _launchUrl(
                                    'https://github.com/Shalin-Shah-2002',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildSocialButton(
                                  icon: Icons.link,
                                  label: 'Portfolio',
                                  onTap: () => _launchUrl(
                                    'https://shalin-portfolio-v1.vercel.app/',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Features Section
                    _buildSectionTitle(context, '🏴‍☠️ Features'),
                    const SizedBox(height: 12),
                    _buildAnimatedCard(
                      delay: 400,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildFeatureItem(
                              Icons.explore,
                              'Discover Anime',
                              'Browse popular and trending anime',
                            ),
                            _buildFeatureItem(
                              Icons.search,
                              'Search',
                              'Find any anime instantly',
                            ),
                            _buildFeatureItem(
                              Icons.bookmark,
                              'Watchlist',
                              'Save anime to watch later',
                            ),
                            _buildFeatureItem(
                              Icons.history,
                              'Watch History',
                              'Track your viewing progress',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Settings Section
                    _buildSectionTitle(context, '⚙️ Settings'),
                    const SizedBox(height: 12),
                    _buildAnimatedCard(
                      delay: 500,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: OnePieceTheme.grandLineBlue
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.settings_ethernet,
                                  color: OnePieceTheme.grandLineBlue,
                                ),
                              ),
                              title: const Text('API Configuration'),
                              subtitle: Text(
                                Get.find<StorageService>()
                                    .getBaseUrlOrDefault(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Get.toNamed('/base-url'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Credits
                    _buildSectionTitle(context, '🌊 Credits'),
                    const SizedBox(height: 12),
                    _buildAnimatedCard(
                      delay: 600,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Powered by HiAnime API',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'One Piece theme inspired by Eiichiro Oda\'s legendary masterpiece',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '© 2024 OtakuHub. Made with ❤️ and dreams of adventure!',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: OnePieceTheme.strawHatGold,
      ),
    );
  }

  Widget _buildAnimatedCard({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: OnePieceTheme.strawHatRed,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OnePieceTheme.grandLineBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: OnePieceTheme.grandLineBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom wave painter for the ocean animation
class WavePainter extends CustomPainter {
  final double waveAnimation;
  final Color waveColor;

  WavePainter({required this.waveAnimation, required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 20.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.7 +
          waveHeight *
              (1 +
                  (x / waveLength + waveAnimation * 2 * 3.14159).remainder(
                        2 * 3.14159,
                      ) /
                      (2 * 3.14159)) *
              (x / waveLength + waveAnimation * 2 * 3.14159)
                  .remainder(2 * 3.14159)
                  .abs();
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave
    final paint2 = Paint()
      ..color = waveColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.8 +
          waveHeight *
              0.7 *
              (1 +
                  (x / waveLength + (waveAnimation + 0.5) * 2 * 3.14159)
                          .remainder(2 * 3.14159) /
                      (2 * 3.14159));
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.waveAnimation != waveAnimation;
  }
}
