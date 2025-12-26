import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/response/stream_response.dart';
import '../models/download_item.dart';
import '../services/api_service.dart';
import '../utils/one_piece_theme.dart';
import '../utils/logger_service.dart';

/// Represents a single subtitle cue with timing and text
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleCue({required this.start, required this.end, required this.text});
}

class MediaKitPlayerScreen extends StatefulWidget {
  final String episodeId;
  final String? episodeTitle;
  final int? episodeNumber;
  final String? animeThumbnail;
  final String? animeTitle;
  final String serverType;
  final String? offlineFilePath;
  final String? offlineStreamUrl;
  final List<DownloadedSubtitle>? offlineSubtitles; // Offline subtitle files

  const MediaKitPlayerScreen({
    super.key,
    required this.episodeId,
    this.episodeTitle,
    this.episodeNumber,
    this.animeThumbnail,
    this.animeTitle,
    this.serverType = 'sub',
    this.offlineFilePath,
    this.offlineStreamUrl,
    this.offlineSubtitles,
  });

  @override
  State<MediaKitPlayerScreen> createState() => _MediaKitPlayerScreenState();
}

class _MediaKitPlayerScreenState extends State<MediaKitPlayerScreen> {
  final ApiService _apiService = ApiService();

  // Media Kit player and controller
  late final Player _player;
  late final VideoController _videoController;

  // Stream data
  StreamResponse? _subStreamData;
  StreamResponse? _dubStreamData;

  // State
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _selectedServerType = 'sub';
  int _selectedServerIndex = 0;

  // Skip buttons
  bool _showSkipIntro = false;
  bool _showSkipOutro = false;

  // Server panel
  bool _showServerPanel = false;

  // Subtitles
  bool _showSubtitlePanel = false;
  int _selectedSubtitleIndex = 0;
  List<SubtitleCue> _subtitleCues = [];
  String _currentSubtitleText = '';
  double _subtitleFontSize = 16.0;
  bool _subtitlesEnabled = true;
  List<DownloadedSubtitle> _offlineSubtitlesList = []; // For offline playback

  // Fullscreen
  bool _isFullscreen = true;

  // Controls visibility
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // Playback state for custom controls
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  bool _playbackStartedSuccessfully = false; // Track if video started playing
  bool _isBuffering = false; // Track buffering state for smooth UX

  // Auto server switch tracking
  bool _isAutoSwitching = false;
  int _currentServerRetries = 0; // Retries for current server
  int _totalServersSwitched = 0; // Total servers tried
  static const int _maxRetriesPerServer =
      2; // Quick retry - only 2 times before switching
  static const int _maxTotalServers = 6; // Max total servers to try

  @override
  void initState() {
    super.initState();
    _selectedServerType = widget.serverType;

    // Initialize media_kit player with OPTIMIZED configuration for instant playback
    // These settings mirror how professional streaming sites (HiAnime, Netflix) achieve smooth playback
    _player = Player(
      configuration: PlayerConfiguration(
        // Buffer size for smooth playback - 150MB demuxer cache (increased for less buffering)
        bufferSize: 150 * 1024 * 1024,
      ),
    );
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: true, // Use GPU for faster decoding
      ),
    );

    // Apply MPV optimizations for fast startup and reduced buffering
    _applyStreamingOptimizations();

    // Enable wakelock
    WakelockPlus.enable();

    // Enter fullscreen
    _enterFullscreen();

    // Load streams
    if (widget.offlineFilePath != null) {
      _loadOfflineFile();
    } else if (widget.offlineStreamUrl != null) {
      _loadOfflineStreamUrl();
    } else {
      _loadAllStreams();
    }

    // Listen to player events
    _setupPlayerListeners();

    // Start auto-hide timer for controls
    _startHideControlsTimer();
  }

  /// Apply MPV streaming optimizations for fast startup and reduced buffering
  /// These settings are applied after player initialization using NativePlayer.setProperty
  Future<void> _applyStreamingOptimizations() async {
    // Access the native player to set MPV properties
    if (_player.platform is NativePlayer) {
      final nativePlayer = _player.platform as NativePlayer;

      try {
        // ═══════════════════════════════════════════════════════════════════════
        // AGGRESSIVE CACHE SETTINGS - Prevent mid-playback buffering
        // ═══════════════════════════════════════════════════════════════════════
        await nativePlayer.setProperty('cache', 'yes');
        await nativePlayer.setProperty(
          'cache-secs',
          '300',
        ); // Cache 5 MINUTES ahead!
        await nativePlayer.setProperty(
          'cache-pause-initial',
          'no',
        ); // Start immediately
        await nativePlayer.setProperty(
          'cache-pause-wait',
          '3',
        ); // Resume when 3s buffered
        await nativePlayer.setProperty(
          'cache-on-disk',
          'yes',
        ); // Use disk cache too

        // ═══════════════════════════════════════════════════════════════════════
        // DEMUXER SETTINGS - Aggressive buffering for HLS streams
        // ═══════════════════════════════════════════════════════════════════════
        await nativePlayer.setProperty(
          'demuxer-readahead-secs',
          '60',
        ); // Read 60s ahead
        await nativePlayer.setProperty(
          'demuxer-max-bytes',
          '150M',
        ); // 150MB demuxer buffer
        await nativePlayer.setProperty(
          'demuxer-max-back-bytes',
          '75M',
        ); // 75MB back buffer

        // ═══════════════════════════════════════════════════════════════════════
        // NETWORK OPTIMIZATION - Critical for streaming stability
        // ═══════════════════════════════════════════════════════════════════════
        await nativePlayer.setProperty(
          'network-timeout',
          '60',
        ); // Longer timeout

        // FFmpeg/lavf options for HLS reconnection and stability
        // This is the KEY setting for preventing buffering!
        await nativePlayer.setProperty(
          'demuxer-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,reconnect_on_network_error=1,reconnect_on_http_error=4xx,reconnect_on_http_error=5xx,fflags=+discardcorrupt+genpts,analyzeduration=0,probesize=32768',
        );

        // ═══════════════════════════════════════════════════════════════════════
        // HLS SPECIFIC - Optimize for anime streaming
        // ═══════════════════════════════════════════════════════════════════════
        await nativePlayer.setProperty('hls-bitrate', 'max'); // Best quality
        await nativePlayer.setProperty('force-seekable', 'yes');

        // ═══════════════════════════════════════════════════════════════════════
        // SEEKING OPTIMIZATION
        // ═══════════════════════════════════════════════════════════════════════
        await nativePlayer.setProperty('hr-seek', 'yes');
        await nativePlayer.setProperty('hr-seek-framedrop', 'yes');

        // ═══════════════════════════════════════════════════════════════════════
        // VIDEO OUTPUT OPTIMIZATION
        // ═══════════════════════════════════════════════════════════════════════
        await nativePlayer.setProperty('video-sync', 'audio'); // Sync to audio
        await nativePlayer.setProperty(
          'framedrop',
          'vo',
        ); // Drop frames if needed

        logger.i(
          'MediaKitPlayer',
          'Applied AGGRESSIVE streaming optimizations',
        );
      } catch (e) {
        logger.w(
          'MediaKitPlayer',
          'Failed to apply some streaming optimizations: $e',
        );
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_showServerPanel) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _setupPlayerListeners() {
    _player.stream.playing.listen((playing) {
      if (mounted) {
        _isPlaying = playing;
        // Mark playback as successful once video starts playing
        if (playing) {
          _playbackStartedSuccessfully = true;
          // Reset error counters on successful play
          _currentServerRetries = 0;
          _totalServersSwitched = 0;
        }
        // Clear error state when video starts playing successfully
        if (playing && _hasError) {
          setState(() {
            _hasError = false;
            _errorMessage = '';
            _isPlaying = playing;
          });
        } else {
          setState(() => _isPlaying = playing);
        }
        // Start hide timer when playing
        if (playing) {
          _startHideControlsTimer();
        }
      }
    });

    _player.stream.position.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
      _checkSkipButtons(position);
      _updateSubtitle(position);
    });

    _player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _player.stream.buffer.listen((buffer) {
      if (mounted) {
        setState(() => _buffer = buffer);
        if (buffer > Duration.zero && _hasError) {
          // Video has buffered content, clear error and reset fail counter
          setState(() {
            _hasError = false;
            _errorMessage = '';
            _currentServerRetries = 0;
            _totalServersSwitched = 0;
            _isAutoSwitching = false;
          });
        }
      }
    });

    // Listen to buffering state for smooth UX indicator
    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() => _isBuffering = buffering);
      }
    });

    _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        // Video completed
        logger.i('MediaKitPlayer', 'Video playback completed');
        setState(() => _showControls = true);
      }
    });

    _player.stream.error.listen((error) {
      if (error.isNotEmpty && mounted && !_isAutoSwitching) {
        // CRITICAL: Don't switch servers if video has already played successfully!
        // Once playback started, we should NOT auto-switch
        if (_playbackStartedSuccessfully) {
          logger.w(
            'MediaKitPlayer',
            'Ignoring error - playback already started: $error',
          );
          return;
        }

        // CRITICAL: Don't switch servers if video is actually playing!
        // Some errors are non-fatal and playback continues fine
        if (_isPlaying || _position.inSeconds > 0 || _buffer.inSeconds > 2) {
          logger.w(
            'MediaKitPlayer',
            'Ignoring error - video is playing: $error',
          );
          _playbackStartedSuccessfully = true; // Mark as successful
          return;
        }

        // Ignore audio device errors (common on iOS Simulator)
        // The video can still play, just without audio on simulator
        if (error.contains('audio device') ||
            error.contains('no sound') ||
            error.contains('Audio output') ||
            error.contains('audio') ||
            error.contains('Audio')) {
          logger.w('MediaKitPlayer', 'Audio device warning (ignored): $error');
          // Don't trigger retry for audio-only issues
          return;
        }

        logger.e('MediaKitPlayer', 'Player error: $error');
        _handlePlaybackError();
      }
    });
  }

  void _handlePlaybackError() {
    _currentServerRetries++;

    logger.i(
      'MediaKitPlayer',
      'Playback error - retry $_currentServerRetries/$_maxRetriesPerServer for current server',
    );

    if (_currentServerRetries < _maxRetriesPerServer) {
      // Retry the same server
      _retryCurrentServer();
    } else {
      // Max retries for this server, switch to next
      _currentServerRetries = 0;
      _totalServersSwitched++;

      if (_totalServersSwitched < _maxTotalServers) {
        _autoSwitchServer();
      } else {
        // All servers exhausted
        setState(() {
          _hasError = true;
          _errorMessage =
              'All servers failed after multiple retries. Tap retry or switch manually.';
          _isAutoSwitching = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _retryCurrentServer() async {
    if (_isAutoSwitching) return;

    setState(() {
      _isAutoSwitching = true;
      _isLoading = true;
    });

    final stream = _getCurrentStream();
    logger.i(
      'MediaKitPlayer',
      'Retrying server ${stream?.serverName ?? "Unknown"} (attempt $_currentServerRetries/$_maxRetriesPerServer)',
    );

    // Quick retry - no delay for better UX
    await Future.delayed(const Duration(milliseconds: 300));

    await _initializePlayer();
    setState(() => _isAutoSwitching = false);
  }

  Future<void> _autoSwitchServer() async {
    if (_isAutoSwitching) return;

    setState(() {
      _isAutoSwitching = true;
      _isLoading = true;
    });

    logger.i(
      'MediaKitPlayer',
      'Switching to next server (total switched: $_totalServersSwitched)',
    );

    final streams = _getCurrentStreams();
    final nextIndex = _selectedServerIndex + 1;

    if (nextIndex < streams.length) {
      // Try next server in same type
      setState(() => _selectedServerIndex = nextIndex);
    } else {
      // Switch to other type
      final otherType = _selectedServerType == 'sub' ? 'dub' : 'sub';
      final otherStreams = otherType == 'sub'
          ? _subStreamData?.streams ?? []
          : _dubStreamData?.streams ?? [];

      if (otherStreams.isNotEmpty) {
        setState(() {
          _selectedServerType = otherType;
          _selectedServerIndex = 0;
        });
      } else {
        // No more servers, reset and show error
        setState(() {
          _hasError = true;
          _errorMessage = 'All servers exhausted. Please try again later.';
          _isLoading = false;
          _isAutoSwitching = false;
        });
        return;
      }
    }

    // Reset retry counter for new server
    _currentServerRetries = 0;

    await _initializePlayer();
    setState(() => _isAutoSwitching = false);
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _loadOfflineFile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final file = File(widget.offlineFilePath!);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found');
      }

      await _player.open(Media(widget.offlineFilePath!));

      // Load offline subtitles if available
      if (widget.offlineSubtitles != null &&
          widget.offlineSubtitles!.isNotEmpty) {
        _offlineSubtitlesList = widget.offlineSubtitles!;
        logger.i(
          'MediaKitPlayer',
          'Found ${_offlineSubtitlesList.length} offline subtitle tracks',
        );

        // Auto-select English subtitle if available, otherwise first one
        final englishIndex = _offlineSubtitlesList.indexWhere(
          (s) =>
              s.language == 'en' || s.label.toLowerCase().contains('english'),
        );
        _selectedSubtitleIndex = englishIndex >= 0 ? englishIndex : 0;

        // Load the selected subtitle
        await _loadOfflineSubtitle(_selectedSubtitleIndex);
      }

      setState(() => _isLoading = false);
      logger.i('MediaKitPlayer', 'Offline file loaded');
    } catch (e) {
      logger.e('MediaKitPlayer', 'Failed to load offline file', error: e);
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOfflineStreamUrl() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _player.open(
        Media(
          widget.offlineStreamUrl!,
          httpHeaders: {
            'Referer': 'https://megacloud.tv/',
            'Origin': 'https://megacloud.tv',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      setState(() => _isLoading = false);
      logger.i('MediaKitPlayer', 'Offline stream URL loaded');
    } catch (e) {
      logger.e('MediaKitPlayer', 'Failed to load offline stream URL', error: e);
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllStreams() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      logger.i('MediaKitPlayer', 'Loading streams for: ${widget.episodeId}');

      // OPTIMIZATION: Load requested type FIRST for instant playback
      // Then load the other type in background for seamless switching
      final primaryType = _selectedServerType;
      final secondaryType = primaryType == 'sub' ? 'dub' : 'sub';

      // Load primary stream immediately
      final primaryStream = await _apiService
          .getStreamingLinks(
            episodeId: widget.episodeId,
            serverType: primaryType,
            includeProxy: true,
          )
          .catchError(
            (e) => StreamResponse(
              success: false,
              episodeId: widget.episodeId,
              serverType: primaryType,
              totalStreams: 0,
              streams: [],
            ),
          );

      // Set primary stream data immediately
      if (primaryType == 'sub') {
        _subStreamData = primaryStream;
      } else {
        _dubStreamData = primaryStream;
      }

      // Start playing immediately if we have streams!
      if (primaryStream.streams.isNotEmpty) {
        // Don't wait - start initializing player NOW
        _initializePlayer();
      }

      // Load secondary stream in background (non-blocking)
      _apiService
          .getStreamingLinks(
            episodeId: widget.episodeId,
            serverType: secondaryType,
            includeProxy: true,
          )
          .then((secondaryStream) {
            if (mounted) {
              setState(() {
                if (secondaryType == 'sub') {
                  _subStreamData = secondaryStream;
                } else {
                  _dubStreamData = secondaryStream;
                }
              });
            }
          })
          .catchError((e) {
            logger.w('MediaKitPlayer', 'Failed to load secondary streams: $e');
          });

      // If primary had no streams, wait for secondary
      if (primaryStream.streams.isEmpty) {
        final secondaryStream = await _apiService
            .getStreamingLinks(
              episodeId: widget.episodeId,
              serverType: secondaryType,
              includeProxy: true,
            )
            .catchError(
              (e) => StreamResponse(
                success: false,
                episodeId: widget.episodeId,
                serverType: secondaryType,
                totalStreams: 0,
                streams: [],
              ),
            );

        if (secondaryType == 'sub') {
          _subStreamData = secondaryStream;
        } else {
          _dubStreamData = secondaryStream;
        }

        // Check if we have streams now
        if (secondaryStream.streams.isNotEmpty) {
          _selectedServerType = secondaryType;
          await _initializePlayer();
        } else {
          throw Exception('No streams available');
        }
      }
    } catch (e, stackTrace) {
      logger.e(
        'MediaKitPlayer',
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
    final stream = _getCurrentStream();
    if (stream == null || stream.sources.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video sources available';
        _isLoading = false;
      });
      return;
    }

    // Try each source - PREFER PROXY URL for faster, more reliable playback
    for (final source in stream.sources) {
      // Use per-source headers - CRITICAL for CDN compatibility!
      // Each CDN (sunburst, rainveil, netmagcdn, etc.) requires different Referer headers
      final headers = source.headers.isNotEmpty
          ? source.headers
          : <String, String>{
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              'Referer': 'https://megacloud.blog/',
              'Origin': 'https://megacloud.blog',
            };

      // TRY PROXY URL FIRST - it's pre-processed and more reliable
      if (source.proxyUrl != null && source.proxyUrl!.isNotEmpty) {
        final proxyUrl = '${_apiService.baseUrl}${source.proxyUrl}';
        logger.d(
          'MediaKitPlayer',
          'Trying proxy URL first (faster): $proxyUrl',
        );

        try {
          await _player.open(
            Media(
              proxyUrl,
              httpHeaders: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36',
              },
            ),
          );

          // Start playback immediately - no delay!
          await _player.play();

          // Hide loading immediately - let the player's own buffering indicator show
          setState(() => _isLoading = false);
          logger.i('MediaKitPlayer', 'Playing via proxy: $proxyUrl');

          // Load subtitles in background (non-blocking)
          if (stream.subtitles.isNotEmpty) {
            Future.microtask(() => _loadSubtitles(stream.subtitles));
          }
          return;
        } catch (e) {
          logger.w('MediaKitPlayer', 'Failed with proxy URL: $e');
        }
      }

      // Fallback to direct URL if proxy fails
      String videoUrl = source.file;
      logger.d('MediaKitPlayer', 'Trying direct URL: $videoUrl');

      try {
        await _player.open(Media(videoUrl, httpHeaders: headers));

        // Start playback immediately
        await _player.play();

        // Hide loading immediately
        setState(() => _isLoading = false);
        logger.i('MediaKitPlayer', 'Playing direct URL: $videoUrl');

        // Load subtitles in background
        if (stream.subtitles.isNotEmpty) {
          Future.microtask(() => _loadSubtitles(stream.subtitles));
        }
        return;
      } catch (e) {
        logger.w('MediaKitPlayer', 'Failed with direct URL: $e');
      }
    }

    // All sources failed, try next server
    await _tryNextServer();
  }

  Future<void> _tryNextServer() async {
    final streams = _getCurrentStreams();
    final nextIndex = _selectedServerIndex + 1;

    if (nextIndex < streams.length) {
      logger.i('MediaKitPlayer', 'Trying next server: $nextIndex');
      setState(() {
        _selectedServerIndex = nextIndex;
      });
      await _initializePlayer();
    } else {
      // Try other type
      final otherType = _selectedServerType == 'sub' ? 'dub' : 'sub';
      final otherStreams = otherType == 'sub'
          ? _subStreamData?.streams ?? []
          : _dubStreamData?.streams ?? [];

      if (otherStreams.isNotEmpty) {
        setState(() {
          _selectedServerType = otherType;
          _selectedServerIndex = 0;
        });
        await _initializePlayer();
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'All servers failed. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _loadSubtitles(List<Subtitle> subtitles) async {
    if (subtitles.isEmpty || _selectedSubtitleIndex < 0) return;

    try {
      final subtitle =
          subtitles[_selectedSubtitleIndex.clamp(0, subtitles.length - 1)];
      // media_kit handles subtitles internally, but we can also parse VTT
      logger.i('MediaKitPlayer', 'Subtitles available: ${subtitle.label}');
    } catch (e) {
      logger.w('MediaKitPlayer', 'Failed to load subtitles: $e');
    }
  }

  /// Load and parse offline VTT subtitle file
  Future<void> _loadOfflineSubtitle(int index) async {
    if (_offlineSubtitlesList.isEmpty ||
        index < 0 ||
        index >= _offlineSubtitlesList.length) {
      return;
    }

    try {
      final subtitle = _offlineSubtitlesList[index];
      final file = File(subtitle.filePath);

      if (!await file.exists()) {
        logger.w(
          'MediaKitPlayer',
          'Subtitle file not found: ${subtitle.filePath}',
        );
        return;
      }

      final content = await file.readAsString();
      final cues = _parseVttSubtitles(content);

      setState(() {
        _subtitleCues = cues;
        _selectedSubtitleIndex = index;
        _currentSubtitleText =
            ''; // Clear current text, will update with position
      });

      logger.i(
        'MediaKitPlayer',
        'Loaded ${cues.length} subtitle cues from ${subtitle.label}',
      );
    } catch (e) {
      logger.e('MediaKitPlayer', 'Failed to load offline subtitle', error: e);
    }
  }

  /// Parse VTT subtitle content into SubtitleCue list
  List<SubtitleCue> _parseVttSubtitles(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');

    int i = 0;

    // Skip WebVTT header
    while (i < lines.length && !lines[i].contains('-->')) {
      i++;
    }

    while (i < lines.length) {
      final line = lines[i].trim();

      // Look for timestamp line (00:00:00.000 --> 00:00:00.000)
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final start = _parseVttTimestamp(parts[0].trim());
          final end = _parseVttTimestamp(
            parts[1].trim().split(' ').first,
          ); // Handle positioning info

          // Collect text lines until empty line or next timestamp
          final textLines = <String>[];
          i++;
          while (i < lines.length) {
            final textLine = lines[i].trim();
            if (textLine.isEmpty || textLine.contains('-->')) {
              break;
            }
            // Skip cue identifiers (numeric or alphanumeric ids)
            if (!RegExp(r'^\d+$').hasMatch(textLine) &&
                !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(textLine)) {
              textLines.add(_cleanVttText(textLine));
            }
            i++;
          }

          if (textLines.isNotEmpty && start != null && end != null) {
            cues.add(
              SubtitleCue(start: start, end: end, text: textLines.join('\n')),
            );
          }
          continue;
        }
      }
      i++;
    }

    return cues;
  }

  /// Parse VTT timestamp (00:00:00.000 or 00:00.000)
  Duration? _parseVttTimestamp(String timestamp) {
    try {
      // Handle both HH:MM:SS.mmm and MM:SS.mmm formats
      final parts = timestamp.split(':');

      int hours = 0;
      int minutes = 0;
      double seconds = 0;

      if (parts.length == 3) {
        hours = int.parse(parts[0]);
        minutes = int.parse(parts[1]);
        seconds = double.parse(parts[2].replaceAll(',', '.'));
      } else if (parts.length == 2) {
        minutes = int.parse(parts[0]);
        seconds = double.parse(parts[1].replaceAll(',', '.'));
      } else {
        return null;
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

  /// Clean VTT text (remove HTML tags and formatting)
  String _cleanVttText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\{[^}]*\}'), '') // Remove ASS-style formatting
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  void _checkSkipButtons(Duration position) {
    final stream = _getCurrentStream();
    if (stream?.skips == null) return;

    final positionSec = position.inSeconds;

    // Skip intro
    if (stream!.skips!.intro != null) {
      final introStart = stream.skips!.intro!.start;
      final introEnd = stream.skips!.intro!.end;
      final shouldShow = positionSec >= introStart && positionSec < introEnd;
      if (_showSkipIntro != shouldShow) {
        setState(() => _showSkipIntro = shouldShow);
      }
    }

    // Skip outro
    if (stream.skips!.outro != null) {
      final outroStart = stream.skips!.outro!.start;
      final outroEnd = stream.skips!.outro!.end;
      final shouldShow = positionSec >= outroStart && positionSec < outroEnd;
      if (_showSkipOutro != shouldShow) {
        setState(() => _showSkipOutro = shouldShow);
      }
    }
  }

  void _updateSubtitle(Duration position) {
    if (!_subtitlesEnabled || _subtitleCues.isEmpty) {
      if (_currentSubtitleText.isNotEmpty) {
        setState(() => _currentSubtitleText = '');
      }
      return;
    }

    // Find the subtitle cue that matches current position
    String newText = '';
    for (final cue in _subtitleCues) {
      if (position >= cue.start && position <= cue.end) {
        newText = cue.text;
        break;
      }
    }

    // Only update state if text changed
    if (newText != _currentSubtitleText) {
      setState(() => _currentSubtitleText = newText);
    }
  }

  void _skipIntro() {
    final stream = _getCurrentStream();
    if (stream?.skips?.intro != null) {
      _player.seek(Duration(seconds: stream!.skips!.intro!.end));
    }
  }

  void _skipOutro() {
    final stream = _getCurrentStream();
    if (stream?.skips?.outro != null) {
      _player.seek(Duration(seconds: stream!.skips!.outro!.end));
    }
  }

  void _switchServer(String type, int index) {
    // Reset all tracking when manually switching
    _currentServerRetries = 0;
    _totalServersSwitched = 0;
    _playbackStartedSuccessfully = false; // Reset for new server

    setState(() {
      _selectedServerType = type;
      _selectedServerIndex = index;
      _isLoading = true;
      _hasError = false;
      _showServerPanel = false;
    });
    _initializePlayer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    WakelockPlus.disable();
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player (fills the entire screen)
            if (_isLoading)
              _buildLoadingState()
            else if (_hasError)
              _buildErrorState()
            else
              Positioned.fill(child: _buildVideoPlayer()),

            // Controls overlay (animated)
            if (!_isLoading && !_hasError) ...[
              // Top Bar - positioned at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _buildTopBar(),
                  ),
                ),
              ),

              // Center play/pause button
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _buildCenterControls(),
                  ),
                ),
              ),

              // Bottom Controls - positioned at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _buildBottomControls(),
                  ),
                ),
              ),

              // Skip Buttons (always visible when applicable)
              _buildSkipButtons(),
            ],

            // Subtitle display - ALWAYS on top of video but below controls
            if (_subtitlesEnabled && _currentSubtitleText.isNotEmpty)
              _buildSubtitleDisplay(),

            // Server Panel (top side)
            if (_showServerPanel) _buildServerPanel(),

            // Subtitle Settings Panel
            if (_showSubtitlePanel) _buildSubtitleSettingsPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleDisplay() {
    // Position subtitles above the bottom controls
    // When controls are visible: higher up to not overlap
    // When controls are hidden: closer to bottom for better viewing
    final bottomPadding = _showControls ? 140.0 : 50.0;

    return Positioned(
      bottom: bottomPadding,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _currentSubtitleText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _subtitleFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final stream = _getCurrentStream();
    final serverName = stream?.serverName ?? 'Unknown';

    String loadingMessage = 'Loading video...';
    if (_isAutoSwitching) {
      if (_currentServerRetries > 0) {
        loadingMessage =
            'Retrying... ($_currentServerRetries/$_maxRetriesPerServer)';
      } else {
        loadingMessage = 'Switching server...';
      }
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                OnePieceTheme.strawHatRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loadingMessage,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            if (_isAutoSwitching) ...[
              const SizedBox(height: 8),
              Text(
                '$serverName (${_selectedServerType.toUpperCase()})',
                style: TextStyle(
                  color: OnePieceTheme.strawHatGold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: OnePieceTheme.strawHatRed,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load video',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadAllStreams,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OnePieceTheme.strawHatRed,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showServerPanel = true),
                  icon: const Icon(Icons.dns),
                  label: const Text('Switch Server'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Video(
          controller: _videoController,
          controls: NoVideoControls, // We use custom controls
        ),
        // Buffering indicator overlay - shows when video is buffering during playback
        if (_isBuffering && !_isLoading)
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      OnePieceTheme.strawHatRed,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Buffering...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCenterControls() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          iconSize: 64,
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
          onPressed: () {
            _player.playOrPause();
            _startHideControlsTimer();
          },
        ),
      ),
    );
  }

  Widget _buildSkipButtons() {
    return Positioned(
      right: 20,
      bottom: 140,
      child: Column(
        children: [
          if (_showSkipIntro)
            ElevatedButton(
              onPressed: () {
                _skipIntro();
                _startHideControlsTimer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: OnePieceTheme.strawHatRed.withOpacity(0.9),
              ),
              child: const Text('Skip Intro'),
            ),
          if (_showSkipOutro)
            ElevatedButton(
              onPressed: () {
                _skipOutro();
                _startHideControlsTimer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: OnePieceTheme.strawHatRed.withOpacity(0.9),
              ),
              child: const Text('Skip Outro'),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final stream = _getCurrentStream();
    final serverName = stream?.serverName ?? 'Unknown';
    final subStreams = _subStreamData?.streams ?? [];
    final dubStreams = _dubStreamData?.streams ?? [];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.animeTitle ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.episodeNumber != null)
                          Text(
                            'Episode ${widget.episodeNumber}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Offline badge
                  if (widget.offlineFilePath != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OFFLINE',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            // Server controls row
            if (widget.offlineFilePath == null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    // Current server info
                    Icon(
                      Icons.dns,
                      color: OnePieceTheme.strawHatGold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      serverName,
                      style: TextStyle(
                        color: OnePieceTheme.strawHatGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // SUB/DUB toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypeToggle('SUB', 'sub', subStreams.length),
                          _buildTypeToggle('DUB', 'dub', dubStreams.length),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Server switch button
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showServerPanel = !_showServerPanel);
                        _startHideControlsTimer();
                      },
                      icon: Icon(
                        Icons.swap_horiz,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        'Switch',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(String label, String type, int count) {
    final isSelected = _selectedServerType == type;
    final isDisabled = count == 0;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              if (_selectedServerType != type) {
                setState(() {
                  _selectedServerType = type;
                  _selectedServerIndex = 0;
                  _isLoading = true;
                  _currentServerRetries = 0;
                  _totalServersSwitched = 0;
                });
                _initializePlayer();
                _startHideControlsTimer();
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? OnePieceTheme.strawHatRed : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isDisabled
                ? Colors.white.withOpacity(0.3)
                : isSelected
                ? Colors.white
                : Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '${twoDigits(hours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildBottomControls() {
    final stream = _getCurrentStream();
    final onlineSubtitles = stream?.subtitles ?? [];

    // Check if we have subtitles available (offline or online)
    final hasSubtitles =
        _offlineSubtitlesList.isNotEmpty || onlineSubtitles.isNotEmpty;

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final bufferProgress = _duration.inMilliseconds > 0
        ? _buffer.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar row
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      // Buffer progress
                      LinearProgressIndicator(
                        value: bufferProgress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.3),
                        ),
                        minHeight: 4,
                      ),
                      // Seek slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                          activeTrackColor: OnePieceTheme.strawHatRed,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: OnePieceTheme.strawHatRed,
                          overlayColor: OnePieceTheme.strawHatRed.withOpacity(
                            0.3,
                          ),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds: (value * _duration.inMilliseconds)
                                  .round(),
                            );
                            _player.seek(newPosition);
                            _startHideControlsTimer();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Playback controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Play/Pause
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    _player.playOrPause();
                    _startHideControlsTimer();
                  },
                ),
                // Rewind 10s
                IconButton(
                  icon: const Icon(
                    Icons.replay_10,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    final newPosition = _position - const Duration(seconds: 10);
                    _player.seek(
                      newPosition < Duration.zero ? Duration.zero : newPosition,
                    );
                    _startHideControlsTimer();
                  },
                ),
                // Forward 10s
                IconButton(
                  icon: const Icon(
                    Icons.forward_10,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    final newPosition = _position + const Duration(seconds: 10);
                    _player.seek(
                      newPosition > _duration ? _duration : newPosition,
                    );
                    _startHideControlsTimer();
                  },
                ),
                // Subtitles button
                IconButton(
                  icon: Icon(
                    _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
                    color: hasSubtitles
                        ? (_subtitlesEnabled
                              ? OnePieceTheme.strawHatGold
                              : Colors.white)
                        : Colors.white.withOpacity(0.3),
                    size: 28,
                  ),
                  onPressed: hasSubtitles
                      ? () {
                          setState(
                            () => _showSubtitlePanel = !_showSubtitlePanel,
                          );
                          _startHideControlsTimer();
                        }
                      : null,
                ),
                // Playback speed
                PopupMenuButton<double>(
                  icon: const Icon(Icons.speed, color: Colors.white, size: 28),
                  color: const Color(0xFF1a1a2e),
                  onSelected: (speed) {
                    _player.setRate(speed);
                    _startHideControlsTimer();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0.5,
                      child: Text(
                        '0.5x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 0.75,
                      child: Text(
                        '0.75x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 1.0,
                      child: Text(
                        '1.0x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 1.25,
                      child: Text(
                        '1.25x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 1.5,
                      child: Text(
                        '1.5x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 2.0,
                      child: Text(
                        '2.0x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleSettingsPanel() {
    final stream = _getCurrentStream();
    final onlineSubtitles = stream?.subtitles ?? [];

    // Use offline subtitles if available, otherwise use online subtitles
    final isOfflineMode =
        widget.offlineFilePath != null && _offlineSubtitlesList.isNotEmpty;
    final subtitleCount = isOfflineMode
        ? _offlineSubtitlesList.length
        : onlineSubtitles.length;
    final hasSubtitles = subtitleCount > 0;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSubtitlePanel = false),
        child: Container(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping panel
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a2e),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.subtitles,
                          color: OnePieceTheme.strawHatGold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Subtitle Settings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isOfflineMode)
                                Text(
                                  'Offline Mode • $subtitleCount subtitle(s)',
                                  style: TextStyle(
                                    color: Colors.green.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () =>
                              setState(() => _showSubtitlePanel = false),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),

                    // Enable/Disable toggle
                    SwitchListTile(
                      title: const Text(
                        'Show Subtitles',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: _subtitlesEnabled,
                      activeThumbColor: OnePieceTheme.strawHatRed,
                      onChanged: (value) {
                        setState(() {
                          _subtitlesEnabled = value;
                          if (!value) {
                            _currentSubtitleText = '';
                          }
                        });
                      },
                    ),

                    // Font size slider
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Font Size: ${_subtitleFontSize.toInt()}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const Spacer(),
                              Text(
                                'Preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _subtitleFontSize,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _subtitleFontSize,
                            min: 12,
                            max: 32,
                            divisions: 10,
                            activeColor: OnePieceTheme.strawHatRed,
                            inactiveColor: Colors.white24,
                            onChanged: (value) =>
                                setState(() => _subtitleFontSize = value),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Small',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Large',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white24),

                    // Subtitle language selection
                    if (hasSubtitles) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Language',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          itemCount: subtitleCount,
                          itemBuilder: (context, index) {
                            final isSelected = _selectedSubtitleIndex == index;

                            // Get label based on mode
                            String label;
                            if (isOfflineMode) {
                              label = _offlineSubtitlesList[index].label;
                            } else {
                              label = onlineSubtitles[index].label;
                            }

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? OnePieceTheme.strawHatGold
                                    : Colors.white54,
                                size: 20,
                              ),
                              title: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? OnePieceTheme.strawHatGold
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isOfflineMode
                                  ? Icon(
                                      Icons.download_done,
                                      color: Colors.green.shade400,
                                      size: 16,
                                    )
                                  : null,
                              onTap: () {
                                setState(() => _selectedSubtitleIndex = index);
                                if (isOfflineMode) {
                                  _loadOfflineSubtitle(index);
                                } else {
                                  _loadSubtitles(onlineSubtitles);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.subtitles_off,
                              color: Colors.white.withOpacity(0.4),
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.offlineFilePath != null
                                  ? 'No subtitles downloaded for this episode'
                                  : 'No subtitles available for this stream',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerPanel() {
    final subStreams = _subStreamData?.streams ?? [];
    final dubStreams = _dubStreamData?.streams ?? [];

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showServerPanel = false),
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Server',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // SUB servers
                  if (subStreams.isNotEmpty) ...[
                    const Text(
                      'SUB',
                      style: TextStyle(color: OnePieceTheme.strawHatGold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(subStreams.length, (i) {
                        final isSelected =
                            _selectedServerType == 'sub' &&
                            _selectedServerIndex == i;
                        return ChoiceChip(
                          label: Text(subStreams[i].serverName),
                          selected: isSelected,
                          onSelected: (_) => _switchServer('sub', i),
                          selectedColor: OnePieceTheme.strawHatRed,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // DUB servers
                  if (dubStreams.isNotEmpty) ...[
                    const Text(
                      'DUB',
                      style: TextStyle(color: OnePieceTheme.strawHatGold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(dubStreams.length, (i) {
                        final isSelected =
                            _selectedServerType == 'dub' &&
                            _selectedServerIndex == i;
                        return ChoiceChip(
                          label: Text(dubStreams[i].serverName),
                          selected: isSelected,
                          onSelected: (_) => _switchServer('dub', i),
                          selectedColor: OnePieceTheme.strawHatRed,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
