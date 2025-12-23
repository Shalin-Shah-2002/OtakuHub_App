import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import '../models/response/stream_response.dart';
import '../services/api_service.dart';
import '../utils/one_piece_theme.dart';
import '../utils/logger_service.dart';
import 'webview_video_player.dart';

/// Represents a single subtitle cue with timing and text
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleCue({required this.start, required this.end, required this.text});
}

class VideoPlayerScreen extends StatefulWidget {
  final String episodeId;
  final String? episodeTitle;
  final int? episodeNumber;
  final String? animeThumbnail;
  final String? animeTitle;
  final String serverType;

  const VideoPlayerScreen({
    super.key,
    required this.episodeId,
    this.episodeTitle,
    this.episodeNumber,
    this.animeThumbnail,
    this.animeTitle,
    this.serverType = 'sub',
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // Stream data for both sub and dub
  StreamResponse? _subStreamData;
  StreamResponse? _dubStreamData;

  // Current state
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _selectedServerType = 'sub';
  int _selectedServerIndex = 0;
  int _currentSourceIndex = 0;
  bool _isRetrying = false;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;

  // Skip button visibility
  bool _showSkipIntro = false;
  bool _showSkipOutro = false;

  // Server panel visibility
  bool _showServerPanel = false;

  // Subtitle state
  bool _showSubtitlePanel = false;
  int _selectedSubtitleIndex = 0; // 0 = first subtitle, -1 = off
  List<SubtitleCue> _subtitleCues = [];
  String _currentSubtitleText = '';
  bool _isLoadingSubtitles = false;
  double _subtitleSize = 18.0; // Default subtitle font size

  // Fullscreen/orientation state
  bool _isFullscreen = true; // Start in fullscreen landscape mode

  // Controls visibility (auto-hide in landscape)
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _selectedServerType = widget.serverType;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    // Controls fade animation
    _controlsAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeInOut,
    );
    _controlsAnimController.forward();

    // Start in landscape fullscreen mode
    _enterFullscreen();

    // Start auto-hide timer
    _startHideControlsTimer();

    _loadAllStreams();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_isFullscreen && !_showServerPanel && !_showSubtitlePanel) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isFullscreen) {
          setState(() => _showControls = false);
          _controlsAnimController.reverse();
        }
      });
    }
  }

  void _toggleControlsVisibility() {
    if (_showControls) {
      // Hide controls
      setState(() => _showControls = false);
      _controlsAnimController.reverse();
      _hideControlsTimer?.cancel();
    } else {
      // Show controls
      setState(() => _showControls = true);
      _controlsAnimController.forward();
      _startHideControlsTimer();
    }
  }

  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
      _showControls = true;
    });
    _controlsAnimController.forward();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideControlsTimer();
  }

  void _exitFullscreen() {
    _hideControlsTimer?.cancel();
    setState(() {
      _isFullscreen = false;
      _showControls = true; // Always show controls in portrait
    });
    _controlsAnimController.forward();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  /// Load streams for both SUB and DUB to enable quick switching
  Future<void> _loadAllStreams() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      logger.i(
        'VideoPlayerScreen',
        'Loading all streams for episode: ${widget.episodeId}',
      );

      // Load SUB and DUB streams in parallel
      final results = await Future.wait([
        _apiService
            .getStreamingLinks(
              episodeId: widget.episodeId,
              serverType: 'sub',
              includeProxy: true,
            )
            .catchError(
              (e) => StreamResponse(
                success: false,
                episodeId: widget.episodeId,
                serverType: 'sub',
                totalStreams: 0,
                streams: [],
              ),
            ),
        _apiService
            .getStreamingLinks(
              episodeId: widget.episodeId,
              serverType: 'dub',
              includeProxy: true,
            )
            .catchError(
              (e) => StreamResponse(
                success: false,
                episodeId: widget.episodeId,
                serverType: 'dub',
                totalStreams: 0,
                streams: [],
              ),
            ),
      ]);

      _subStreamData = results[0];
      _dubStreamData = results[1];

      // Check if we have any streams
      final currentStreams = _getCurrentStreams();
      if (currentStreams.isEmpty) {
        // Try the other type
        if (_selectedServerType == 'sub' &&
            _dubStreamData!.streams.isNotEmpty) {
          _selectedServerType = 'dub';
        } else if (_selectedServerType == 'dub' &&
            _subStreamData!.streams.isNotEmpty) {
          _selectedServerType = 'sub';
        } else {
          throw Exception('No streams available for this episode');
        }
      }

      await _initializePlayer();
    } catch (e, stackTrace) {
      logger.e(
        'VideoPlayerScreen',
        'Failed to load streams',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<StreamData> _getCurrentStreams() {
    if (_selectedServerType == 'sub') {
      return _subStreamData?.streams ?? [];
    } else {
      return _dubStreamData?.streams ?? [];
    }
  }

  StreamData? _getCurrentStream() {
    final streams = _getCurrentStreams();
    if (_selectedServerIndex < streams.length) {
      return streams[_selectedServerIndex];
    }
    return streams.isNotEmpty ? streams.first : null;
  }

  Future<void> _initializePlayer() async {
    await _disposeControllers();

    final stream = _getCurrentStream();
    if (stream == null || stream.sources.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video sources available';
        _isLoading = false;
      });
      return;
    }

    // Build list of URLs to try in order
    List<Map<String, dynamic>> urlsToTry = [];

    for (int i = _currentSourceIndex; i < stream.sources.length; i++) {
      final source = stream.sources[i];

      // Try 1: Direct URL with headers (often works better on iOS)
      if (source.file.isNotEmpty) {
        urlsToTry.add({
          'url': source.file,
          'headers': stream.headers,
          'description': 'Direct URL with headers',
          'sourceIndex': i,
        });
      }

      // Try 2: Proxy URL (no headers)
      if (source.proxyUrl != null && source.proxyUrl!.isNotEmpty) {
        urlsToTry.add({
          'url': '${_apiService.baseUrl}${source.proxyUrl}',
          'headers': <String, String>{},
          'description': 'Proxy URL',
          'sourceIndex': i,
        });
      }
    }

    // Try each URL
    for (final urlConfig in urlsToTry) {
      final videoUrl = urlConfig['url'] as String;
      final headers = urlConfig['headers'] as Map<String, String>;
      final description = urlConfig['description'] as String;
      final sourceIndex = urlConfig['sourceIndex'] as int;

      logger.d('VideoPlayerScreen', 'Trying $description: $videoUrl');

      try {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: headers,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );

        await _videoController!.initialize();

        // Check if video actually has duration (valid stream)
        if (_videoController!.value.duration.inSeconds == 0) {
          throw Exception('Invalid video stream - zero duration');
        }

        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          aspectRatio: _videoController!.value.aspectRatio,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
          placeholder: _buildPlaceholder(),
          materialProgressColors: ChewieProgressColors(
            playedColor: OnePieceTheme.strawHatRed,
            handleColor: OnePieceTheme.strawHatGold,
            backgroundColor: Colors.grey.shade800,
            bufferedColor: OnePieceTheme.strawHatRed.withAlpha(76),
          ),
          errorBuilder: (context, errorMessage) =>
              _buildInlineError(errorMessage),
        );

        // Listen for position changes to show skip buttons
        _videoController!.addListener(_onVideoPositionChanged);

        setState(() {
          _isLoading = false;
          _currentSourceIndex = sourceIndex;
        });

        // Auto-load subtitles if available
        final currentStream = _getCurrentStream();
        if (currentStream != null &&
            currentStream.subtitles.isNotEmpty &&
            _selectedSubtitleIndex >= 0) {
          _loadSubtitles();
        }

        logger.i(
          'VideoPlayerScreen',
          'Successfully initialized with $description',
        );
        return;
      } catch (e) {
        logger.w('VideoPlayerScreen', 'Failed with $description: $e');
        await _disposeControllers();
        continue;
      }
    }

    // If we get here, all sources failed - try next server
    if (!_isRetrying) {
      _isRetrying = true;
      await _tryNextServer();
    } else {
      setState(() {
        _hasError = true;
        _errorMessage =
            'All video sources failed. Please try a different server.';
        _isLoading = false;
        _isRetrying = false;
      });
    }
  }

  Future<void> _tryNextServer() async {
    final streams = _getCurrentStreams();
    final nextIndex = _selectedServerIndex + 1;

    if (nextIndex < streams.length) {
      logger.i('VideoPlayerScreen', 'Trying next server: $nextIndex');
      setState(() {
        _selectedServerIndex = nextIndex;
        _currentSourceIndex = 0;
      });
      await _initializePlayer();
    } else {
      // Try switching to other audio type
      final otherType = _selectedServerType == 'sub' ? 'dub' : 'sub';
      final otherStreams = otherType == 'sub'
          ? _subStreamData?.streams ?? []
          : _dubStreamData?.streams ?? [];

      if (otherStreams.isNotEmpty) {
        logger.i('VideoPlayerScreen', 'Trying $otherType streams');
        setState(() {
          _selectedServerType = otherType;
          _selectedServerIndex = 0;
          _currentSourceIndex = 0;
        });
        await _initializePlayer();
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'All servers failed. Please try again later.';
          _isLoading = false;
          _isRetrying = false;
        });
      }
    }
  }

  void _onVideoPositionChanged() {
    final stream = _getCurrentStream();
    if (stream == null) return;

    final position = _videoController?.value.position ?? Duration.zero;
    final positionSeconds = position.inSeconds;

    // Check intro skip
    final skips = stream.skips;
    if (skips != null) {
      if (skips.intro != null) {
        final showIntro =
            positionSeconds >= skips.intro!.start &&
            positionSeconds < skips.intro!.end;
        if (showIntro != _showSkipIntro) {
          setState(() => _showSkipIntro = showIntro);
        }
      }

      // Check outro skip
      if (skips.outro != null) {
        final showOutro =
            positionSeconds >= skips.outro!.start &&
            positionSeconds < skips.outro!.end;
        if (showOutro != _showSkipOutro) {
          setState(() => _showSkipOutro = showOutro);
        }
      }
    }

    // Update current subtitle
    if (_selectedSubtitleIndex >= 0 && _subtitleCues.isNotEmpty) {
      String newText = '';
      for (final cue in _subtitleCues) {
        if (position >= cue.start && position <= cue.end) {
          newText = cue.text;
          break;
        }
      }
      if (newText != _currentSubtitleText) {
        setState(() => _currentSubtitleText = newText);
      }
    }
  }

  void _skipIntro() {
    final skips = _getCurrentStream()?.skips;
    if (skips?.intro != null) {
      _videoController?.seekTo(Duration(seconds: skips!.intro!.end));
    }
  }

  void _skipOutro() {
    final skips = _getCurrentStream()?.skips;
    if (skips?.outro != null) {
      _videoController?.seekTo(Duration(seconds: skips!.outro!.end));
    }
  }

  /// Load and parse subtitles for the selected subtitle index
  Future<void> _loadSubtitles() async {
    final stream = _getCurrentStream();
    if (stream == null || _selectedSubtitleIndex < 0) {
      setState(() {
        _subtitleCues = [];
        _currentSubtitleText = '';
      });
      return;
    }

    final subtitles = stream.subtitles;
    if (_selectedSubtitleIndex >= subtitles.length) {
      return;
    }

    final subtitle = subtitles[_selectedSubtitleIndex];
    final url = subtitle.file;

    if (url.isEmpty) return;

    setState(() => _isLoadingSubtitles = true);

    try {
      logger.d('VideoPlayerScreen', 'Loading subtitles from: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final content = response.body;
        final cues = _parseVttContent(content);
        setState(() {
          _subtitleCues = cues;
          _isLoadingSubtitles = false;
        });
        logger.i('VideoPlayerScreen', 'Loaded ${cues.length} subtitle cues');
      } else {
        logger.w(
          'VideoPlayerScreen',
          'Failed to load subtitles: ${response.statusCode}',
        );
        setState(() => _isLoadingSubtitles = false);
      }
    } catch (e) {
      logger.e('VideoPlayerScreen', 'Error loading subtitles', error: e);
      setState(() => _isLoadingSubtitles = false);
    }
  }

  /// Parse VTT/SRT subtitle content into cues
  List<SubtitleCue> _parseVttContent(String content) {
    final List<SubtitleCue> cues = [];

    // Split into blocks
    final blocks = content.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty) continue;

      // Skip WEBVTT header and metadata
      if (lines[0].startsWith('WEBVTT') || lines[0].startsWith('NOTE'))
        continue;

      // Find timing line (contains -->)
      int timingLineIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timingLineIndex = i;
          break;
        }
      }

      if (timingLineIndex == -1) continue;

      // Parse timing
      final timingLine = lines[timingLineIndex];
      final timingParts = timingLine.split('-->');
      if (timingParts.length != 2) continue;

      final start = _parseTimestamp(timingParts[0].trim());
      final end = _parseTimestamp(
        timingParts[1].trim().split(' ')[0],
      ); // Remove position info

      if (start == null || end == null) continue;

      // Get text (all lines after timing)
      final textLines = lines.sublist(timingLineIndex + 1);
      if (textLines.isEmpty) continue;

      // Join text lines and clean HTML tags
      String text = textLines.join('\n');
      text = text.replaceAll(RegExp(r'<[^>]*>'), ''); // Remove HTML tags
      text = text.trim();

      if (text.isNotEmpty) {
        cues.add(SubtitleCue(start: start, end: end, text: text));
      }
    }

    return cues;
  }

  /// Parse VTT/SRT timestamp to Duration
  Duration? _parseTimestamp(String timestamp) {
    try {
      // Handle both VTT (00:00:00.000) and SRT (00:00:00,000) formats
      timestamp = timestamp.replaceAll(',', '.');

      final parts = timestamp.split(':');
      if (parts.length < 2) return null;

      int hours = 0;
      int minutes = 0;
      double seconds = 0;

      if (parts.length == 3) {
        hours = int.parse(parts[0]);
        minutes = int.parse(parts[1]);
        seconds = double.parse(parts[2]);
      } else if (parts.length == 2) {
        minutes = int.parse(parts[0]);
        seconds = double.parse(parts[1]);
      }

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds.floor(),
        milliseconds: ((seconds - seconds.floor()) * 1000).round(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _switchServer(String type, int index) async {
    if (type == _selectedServerType && index == _selectedServerIndex) return;

    setState(() {
      _selectedServerType = type;
      _selectedServerIndex = index;
      _currentSourceIndex = 0;
      _isLoading = true;
      _isRetrying = false;
      _showServerPanel = false;
    });

    await _initializePlayer();
  }

  Future<void> _disposeControllers() async {
    _videoController?.removeListener(_onVideoPositionChanged);
    _chewieController?.dispose();
    await _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _fadeController.dispose();
    _controlsAnimController.dispose();
    _disposeControllers();

    // Reset orientation and system UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: widget.animeThumbnail != null
            ? Image.network(
                widget.animeThumbnail!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.movie, size: 80, color: Colors.white30),
              )
            : const Icon(Icons.movie, size: 80, color: Colors.white30),
      ),
    );
  }

  Widget _buildInlineError(String message) {
    final hasStream = _getCurrentStream() != null;

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: OnePieceTheme.strawHatRed,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _loadAllStreams(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OnePieceTheme.strawHatRed,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showServerPanel = true),
                  icon: const Icon(Icons.dns, size: 18),
                  label: const Text('Switch Server'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ],
            ),
            if (hasStream) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _openWebViewPlayer(),
                icon: const Icon(Icons.web, size: 16),
                label: const Text('Try Web Player'),
                style: TextButton.styleFrom(
                  foregroundColor: OnePieceTheme.strawHatGold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isFullscreen, // Only safe area in portrait
        bottom: !_isFullscreen,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // Main Content - Video takes full screen in landscape
              GestureDetector(
                onTap: _isFullscreen ? _toggleControlsVisibility : null,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    // Video Player Area
                    Expanded(
                      child: Stack(
                        children: [
                          // Video Player or Loading/Error State
                          if (_isLoading)
                            _buildLoadingState()
                          else if (_hasError)
                            _buildErrorState()
                          else if (_chewieController != null)
                            Chewie(controller: _chewieController!),

                          // Subtitle Overlay (always visible)
                          if (!_isLoading &&
                              !_hasError &&
                              _selectedSubtitleIndex >= 0)
                            _buildSubtitleOverlay(),

                          // Skip Buttons Overlay (always visible)
                          if (!_isLoading && !_hasError) _buildSkipButtons(),

                          // Top Bar (animated visibility in fullscreen)
                          if (_isFullscreen)
                            FadeTransition(
                              opacity: _controlsAnimation,
                              child: IgnorePointer(
                                ignoring: !_showControls,
                                child: _buildTopBar(),
                              ),
                            )
                          else
                            _buildTopBar(),
                        ],
                      ),
                    ),

                    // Bottom Server Bar (animated visibility in fullscreen)
                    if (_isFullscreen)
                      FadeTransition(
                        opacity: _controlsAnimation,
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: _buildBottomBar(),
                        ),
                      )
                    else
                      _buildBottomBar(),
                  ],
                ),
              ),

              // Server Selection Panel (Overlay)
              if (_showServerPanel) _buildServerPanel(),

              // Subtitle Selection Panel (Overlay)
              if (_showSubtitlePanel) _buildSubtitlePanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      OnePieceTheme.strawHatRed,
                    ),
                  ),
                ),
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 40,
                  color: OnePieceTheme.strawHatGold,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _isRetrying ? 'Trying another server...' : 'Loading stream...',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (widget.animeTitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.animeTitle!,
                style: const TextStyle(
                  color: OnePieceTheme.strawHatGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final stream = _getCurrentStream();
    final hasVideoUrl = stream != null && stream.sources.isNotEmpty;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: OnePieceTheme.strawHatRed.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: OnePieceTheme.strawHatRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to Load Stream',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),

            // Primary action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showServerPanel = true),
                  icon: const Icon(Icons.dns),
                  label: const Text('Try Other Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OnePieceTheme.strawHatRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            // WebView fallback button
            if (hasVideoUrl) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                'Native player not working? Try the web player:',
                style: TextStyle(
                  color: Colors.white.withAlpha(153),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _openWebViewPlayer(),
                icon: const Icon(Icons.web),
                label: const Text('Open Web Player'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OnePieceTheme.strawHatGold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openWebViewPlayer() {
    final stream = _getCurrentStream();
    if (stream == null || stream.sources.isEmpty) return;

    final source = stream.sources.first;
    String videoUrl = source.file;

    // Prefer proxy URL for WebView too (avoids CORS)
    if (source.proxyUrl != null && source.proxyUrl!.isNotEmpty) {
      videoUrl = '${_apiService.baseUrl}${source.proxyUrl}';
    }

    // Get skip times
    Map<String, int>? introSkip;
    Map<String, int>? outroSkip;

    if (stream.skips?.intro != null) {
      introSkip = {
        'start': stream.skips!.intro!.start,
        'end': stream.skips!.intro!.end,
      };
    }
    if (stream.skips?.outro != null) {
      outroSkip = {
        'start': stream.skips!.outro!.start,
        'end': stream.skips!.outro!.end,
      };
    }

    // Collect subtitles
    List<Map<String, String>>? subtitles;
    if (stream.subtitles.isNotEmpty) {
      subtitles = stream.subtitles
          .map(
            (sub) => {
              'url': sub.file,
              'label': sub.label,
              'kind': sub.kind,
              'lang': sub.label.toLowerCase().contains('english') ? 'en' : 'ja',
            },
          )
          .toList();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewVideoPlayer(
          videoUrl: videoUrl,
          episodeTitle: widget.episodeTitle,
          episodeNumber: widget.episodeNumber,
          animeTitle: widget.animeTitle,
          introSkip: introSkip,
          outroSkip: outroSkip,
          subtitles: subtitles,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withAlpha(204), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // Reset to portrait before leaving
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                ]);
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.animeTitle != null)
                    Text(
                      widget.animeTitle!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    widget.episodeTitle ??
                        'Episode ${widget.episodeNumber ?? ''}',
                    style: const TextStyle(
                      color: OnePieceTheme.strawHatGold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Current server indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: OnePieceTheme.strawHatRed.withAlpha(179),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _selectedServerType.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Fullscreen toggle button
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleFullscreen,
              tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final subCount = _subStreamData?.streams.length ?? 0;
    final dubCount = _dubStreamData?.streams.length ?? 0;
    final currentStream = _getCurrentStream();

    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Server info
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showServerPanel = !_showServerPanel),
              child: Row(
                children: [
                  Icon(
                    Icons.dns_rounded,
                    color: OnePieceTheme.strawHatGold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentStream?.name ?? 'Select Server',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'SUB: $subCount servers • DUB: $dubCount servers',
                          style: TextStyle(
                            color: Colors.white.withAlpha(153),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // CC (Subtitles) button
          if (_getCurrentStream()?.subtitles.isNotEmpty == true)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showSubtitlePanel = !_showSubtitlePanel;
                  _showServerPanel = false;
                });
                _hideControlsTimer
                    ?.cancel(); // Keep controls visible while panel is open
              },
              icon: Icon(
                Icons.closed_caption,
                size: 18,
                color: _selectedSubtitleIndex >= 0
                    ? OnePieceTheme.strawHatGold
                    : Colors.white54,
              ),
              label: Text(
                'CC',
                style: TextStyle(
                  color: _selectedSubtitleIndex >= 0
                      ? OnePieceTheme.strawHatGold
                      : Colors.white54,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: OnePieceTheme.strawHatGold,
              ),
            ),
          // Switch server button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showServerPanel = !_showServerPanel;
                _showSubtitlePanel = false;
              });
              _hideControlsTimer
                  ?.cancel(); // Keep controls visible while panel is open
            },
            icon: Icon(
              _showServerPanel ? Icons.expand_more : Icons.expand_less,
              size: 18,
            ),
            label: const Text('Servers'),
            style: TextButton.styleFrom(
              foregroundColor: OnePieceTheme.strawHatGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlePanel() {
    final stream = _getCurrentStream();
    final subtitles = stream?.subtitles ?? [];

    if (subtitles.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withAlpha(25)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.closed_caption,
                      color: OnePieceTheme.strawHatGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Subtitles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _showSubtitlePanel = false);
                        _startHideControlsTimer();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Subtitle options
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Size customization
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.text_fields,
                                  color: OnePieceTheme.strawHatGold,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Size',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_subtitleSize.round()}',
                                  style: const TextStyle(
                                    color: OnePieceTheme.strawHatGold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: OnePieceTheme.strawHatRed,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: OnePieceTheme.strawHatGold,
                                overlayColor: OnePieceTheme.strawHatGold
                                    .withAlpha(30),
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: _subtitleSize,
                                min: 12,
                                max: 32,
                                onChanged: (value) {
                                  setState(() => _subtitleSize = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Off option
                      _buildSubtitleOption(
                        label: 'Off',
                        isSelected: _selectedSubtitleIndex == -1,
                        onTap: () {
                          setState(() {
                            _selectedSubtitleIndex = -1;
                            _subtitleCues = [];
                            _currentSubtitleText = '';
                            _showSubtitlePanel = false;
                          });
                          _startHideControlsTimer();
                        },
                      ),
                      const SizedBox(height: 8),
                      // Subtitle options
                      ...subtitles.asMap().entries.map((entry) {
                        final index = entry.key;
                        final subtitle = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildSubtitleOption(
                            label: subtitle.label,
                            isSelected: _selectedSubtitleIndex == index,
                            onTap: () {
                              setState(() {
                                _selectedSubtitleIndex = index;
                                _showSubtitlePanel = false;
                              });
                              _loadSubtitles();
                              _startHideControlsTimer();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? OnePieceTheme.strawHatRed.withAlpha(51)
              : Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? OnePieceTheme.strawHatRed : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? OnePieceTheme.strawHatGold : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleOverlay() {
    if (_isLoadingSubtitles) {
      return Positioned(
        bottom: 80,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      OnePieceTheme.strawHatGold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading subtitles...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentSubtitleText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentSubtitleText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _subtitleSize,
                fontWeight: FontWeight.w500,
                height: 1.4,
                shadows: const [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerPanel() {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {}, // Prevent tap through
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withAlpha(25)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_input_antenna,
                      color: OnePieceTheme.strawHatGold,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Server',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _showServerPanel = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Server lists
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SUB Servers
                      if (_subStreamData != null &&
                          _subStreamData!.streams.isNotEmpty) ...[
                        _buildServerSection(
                          'SUB',
                          'sub',
                          _subStreamData!.streams,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // DUB Servers
                      if (_dubStreamData != null &&
                          _dubStreamData!.streams.isNotEmpty)
                        _buildServerSection(
                          'DUB',
                          'dub',
                          _dubStreamData!.streams,
                        ),

                      // No servers message
                      if ((_subStreamData?.streams.isEmpty ?? true) &&
                          (_dubStreamData?.streams.isEmpty ?? true))
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No servers available',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerSection(
    String label,
    String type,
    List<StreamData> streams,
  ) {
    final isCurrentType = _selectedServerType == type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentType
                    ? OnePieceTheme.strawHatRed
                    : Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type == 'sub' ? Icons.subtitles : Icons.mic,
                    size: 14,
                    color: isCurrentType ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isCurrentType ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${streams.length} ${streams.length == 1 ? 'server' : 'servers'}',
              style: TextStyle(
                color: Colors.white.withAlpha(102),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Server chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(streams.length, (index) {
            final stream = streams[index];
            final isSelected = isCurrentType && _selectedServerIndex == index;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _switchServer(type, index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? OnePieceTheme.strawHatRed
                        : Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? OnePieceTheme.strawHatGold
                          : Colors.white.withAlpha(25),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.play_circle_outline,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stream.serverName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (stream.sources.isNotEmpty &&
                          stream.sources.first.quality != 'auto') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stream.sources.first.quality.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSkipButtons() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showSkipIntro) _buildSkipButton('Skip Intro', _skipIntro),
          if (_showSkipOutro) ...[
            if (_showSkipIntro) const SizedBox(height: 8),
            _buildSkipButton('Skip Outro', _skipOutro),
          ],
        ],
      ),
    );
  }

  Widget _buildSkipButton(String label, VoidCallback onTap) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: OnePieceTheme.strawHatRed.withAlpha(230),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: OnePieceTheme.strawHatGold.withAlpha(128),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fast_forward, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
