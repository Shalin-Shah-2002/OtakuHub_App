import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../utils/one_piece_theme.dart';

class BaseUrlScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const BaseUrlScreen({super.key, this.isFirstLaunch = false});

  @override
  State<BaseUrlScreen> createState() => _BaseUrlScreenState();
}

class _BaseUrlScreenState extends State<BaseUrlScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isValidating = false;
  String? _validationMessage;
  bool _isValid = false;

  // GitHub repo URL for the API
  static const String _apiRepoUrl =
      'https://github.com/Shalin-Shah-2002/Hianime_API';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Load existing URL if any
    _loadExistingUrl();
  }

  void _loadExistingUrl() {
    final storageService = Get.find<StorageService>();
    final existingUrl = storageService.getBaseUrl();
    if (existingUrl != null && existingUrl.isNotEmpty) {
      _urlController.text = existingUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isValidating = true;
      _validationMessage = null;
    });

    final url = _urlController.text.trim();

    // Basic URL validation
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() {
        _isValidating = false;
        _validationMessage = 'URL must start with http:// or https://';
        _isValid = false;
      });
      return;
    }

    // Test the API endpoint
    try {
      // Simple connection test
      final response = await Get.find<StorageService>().testApiConnection(url);

      if (response) {
        setState(() {
          _isValidating = false;
          _validationMessage = '✅ Connection successful! API is working.';
          _isValid = true;
        });

        // Save the URL
        await Get.find<StorageService>().setBaseUrl(url);

        // Mark first launch as complete if this is first launch
        if (widget.isFirstLaunch) {
          await Get.find<StorageService>().setFirstLaunchComplete();
        }

        // Show success snackbar
        Get.snackbar(
          '🎉 Success!',
          'Base URL saved successfully!',
          backgroundColor: OnePieceTheme.strawHatGold.withOpacity(0.9),
          colorText: Colors.black,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );

        // Navigate based on context
        await Future.delayed(const Duration(milliseconds: 500));
        if (widget.isFirstLaunch) {
          Get.offAllNamed('/home');
        } else {
          Get.back(result: true);
        }
      } else {
        setState(() {
          _isValidating = false;
          _validationMessage =
              '❌ Could not connect to API. Please check the URL.';
          _isValid = false;
        });
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
        _validationMessage = '❌ Error: ${e.toString()}';
        _isValid = false;
      });
    }
  }

  Future<void> _launchGitHub() async {
    final uri = Uri.parse(_apiRepoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [OnePieceTheme.deepSea, const Color(0xFF0D1B2A)]
                : [OnePieceTheme.grandLineBlue.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with skip button for non-first launch
                      if (!widget.isFirstLaunch)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.close),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Anchor Icon with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
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
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.settings_ethernet,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        widget.isFirstLaunch
                            ? 'Welcome, Nakama! ⚓'
                            : 'API Configuration',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: OnePieceTheme.strawHatRed,
                            ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.isFirstLaunch
                            ? 'Set up your anime API to start your adventure!'
                            : 'Update your HiAnime API base URL',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Instructions Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? OnePieceTheme.grandLineBlue.withOpacity(0.2)
                              : OnePieceTheme.grandLineBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: OnePieceTheme.grandLineBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: OnePieceTheme.grandLineBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Setup Instructions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: OnePieceTheme.grandLineBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionStep(
                              '1',
                              'Go to the GitHub repo below',
                              isDark,
                            ),
                            _buildInstructionStep(
                              '2',
                              'Deploy to Render (free hosting)',
                              isDark,
                            ),
                            _buildInstructionStep(
                              '3',
                              'Add HiAnime web URL in environment variables',
                              isDark,
                            ),
                            _buildInstructionStep(
                              '4',
                              'Copy your Render server URL and paste below',
                              isDark,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // GitHub Button
                      OutlinedButton.icon(
                        onPressed: _launchGitHub,
                        icon: const Icon(Icons.code),
                        label: const Text('Open HiAnime API GitHub'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OnePieceTheme.strawHatRed,
                          side: const BorderSide(
                            color: OnePieceTheme.strawHatRed,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // URL Input Field
                      TextFormField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'https://your-api.onrender.com',
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste),
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                Clipboard.kTextPlain,
                              );
                              if (data?.text != null) {
                                _urlController.text = data!.text!;
                              }
                            },
                            tooltip: 'Paste from clipboard',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: OnePieceTheme.strawHatRed,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a base URL';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Validation Message
                      if (_validationMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isValid
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isValid
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _validationMessage!,
                            style: TextStyle(
                              color: _isValid ? Colors.green : Colors.red,
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Save Button
                      ElevatedButton(
                        onPressed: _isValidating ? null : _validateAndSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OnePieceTheme.strawHatRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isValidating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Validate & Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Default URL option
                      TextButton(
                        onPressed: () {
                          _urlController.text =
                              'https://hianime-api-b6ix.onrender.com';
                        },
                        child: Text(
                          'Use Default API URL',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),

                      if (widget.isFirstLaunch) ...[
                        const SizedBox(height: 32),
                        // Skip for now (uses default)
                        TextButton(
                          onPressed: () async {
                            await Get.find<StorageService>().setBaseUrl(
                              'https://hianime-api-b6ix.onrender.com',
                            );
                            await Get.find<StorageService>()
                                .setFirstLaunchComplete();
                            Get.offAllNamed('/home');
                          },
                          child: const Text(
                            'Skip (Use Default API) →',
                            style: TextStyle(
                              color: OnePieceTheme.strawHatGold,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: OnePieceTheme.strawHatRed,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
