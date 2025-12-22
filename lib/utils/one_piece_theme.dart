import 'package:flutter/material.dart';

/// One Piece themed colors and styles
class OnePieceTheme {
  // Primary Colors - Luffy's Red
  static const Color strawHatRed = Color(0xFFD32F2F);
  static const Color luffyRed = Color(0xFFB71C1C);
  static const Color darkRed = Color(0xFF8B0000);

  // Secondary Colors - Straw Hat Gold/Yellow
  static const Color strawHatGold = Color(0xFFFFD700);
  static const Color sunnyGold = Color(0xFFFFC107);
  static const Color treasureGold = Color(0xFFFFAB00);

  // Ocean Colors
  static const Color grandLineBlue = Color(0xFF1565C0);
  static const Color oceanBlue = Color(0xFF0D47A1);
  static const Color seaBlue = Color(0xFF42A5F5);
  static const Color deepSea = Color(0xFF0A1929);

  // Accent Colors
  static const Color jollyRogerBlack = Color(0xFF212121);
  static const Color parchment = Color(0xFFFFF8E1);
  static const Color skyIsland = Color(0xFF81D4FA);

  // Gradient colors for backgrounds
  static const LinearGradient oceanGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepSea, oceanBlue, grandLineBlue],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [strawHatRed, treasureGold],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
  );

  /// Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: strawHatRed,
        onPrimary: Colors.white,
        secondary: strawHatGold,
        onSecondary: jollyRogerBlack,
        tertiary: grandLineBlue,
        surface: Colors.white,
        onSurface: jollyRogerBlack,
        error: Colors.red.shade700,
        primaryContainer: strawHatRed.withOpacity(0.1),
        secondaryContainer: strawHatGold.withOpacity(0.2),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: strawHatRed,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: strawHatRed.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: strawHatRed,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: strawHatRed);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: strawHatRed.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: strawHatRed,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: strawHatGold,
        foregroundColor: jollyRogerBlack,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: grandLineBlue.withOpacity(0.1),
        labelStyle: const TextStyle(color: grandLineBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: strawHatRed, width: 2),
        ),
      ),
    );
  }

  /// Dark Theme - Grand Line Night
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: strawHatRed,
        onPrimary: Colors.white,
        secondary: strawHatGold,
        onSecondary: jollyRogerBlack,
        tertiary: seaBlue,
        surface: const Color(0xFF121212),
        onSurface: Colors.white,
        error: Colors.red.shade400,
        primaryContainer: strawHatRed.withOpacity(0.2),
        secondaryContainer: strawHatGold.withOpacity(0.2),
      ),
      scaffoldBackgroundColor: deepSea,
      appBarTheme: AppBarTheme(
        backgroundColor: deepSea,
        foregroundColor: strawHatGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: strawHatGold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: strawHatRed.withOpacity(0.3),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: strawHatGold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return TextStyle(color: Colors.grey.shade400, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: strawHatGold);
          }
          return IconThemeData(color: Colors.grey.shade400);
        }),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E),
        elevation: 8,
        shadowColor: strawHatRed.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: strawHatRed,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: strawHatGold,
        foregroundColor: jollyRogerBlack,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: grandLineBlue.withOpacity(0.3),
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: strawHatGold, width: 2),
        ),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
      listTileTheme: const ListTileThemeData(iconColor: strawHatGold),
      iconTheme: const IconThemeData(color: strawHatGold),
      dividerTheme: DividerThemeData(color: Colors.grey.shade800),
    );
  }
}

/// Custom animated card widget with One Piece styling
class OnePieceCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool showGlow;

  const OnePieceCard({
    super.key,
    required this.child,
    this.onTap,
    this.showGlow = false,
  });

  @override
  State<OnePieceCard> createState() => _OnePieceCardState();
}

class _OnePieceCardState extends State<OnePieceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: widget.showGlow
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: OnePieceTheme.strawHatGold.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Card(clipBehavior: Clip.antiAlias, child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

/// Animated pirate flag widget
class PirateFlagIcon extends StatefulWidget {
  final double size;
  final Color color;

  const PirateFlagIcon({
    super.key,
    this.size = 24,
    this.color = OnePieceTheme.strawHatGold,
  });

  @override
  State<PirateFlagIcon> createState() => _PirateFlagIconState();
}

class _PirateFlagIconState extends State<PirateFlagIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: 0.1 * _controller.value - 0.05,
          child: Icon(Icons.flag, size: widget.size, color: widget.color),
        );
      },
    );
  }
}
