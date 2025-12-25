import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/one_piece_theme.dart';

/// WebView-based video player for HLS streams
/// This is used as a fallback when native video_player fails
class WebViewVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? episodeTitle;
  final int? episodeNumber;
  final String? animeTitle;
  final Map<String, int>? introSkip;
  final Map<String, int>? outroSkip;
  final List<Map<String, String>>? subtitles; // [{url, label, kind}]

  const WebViewVideoPlayer({
    super.key,
    required this.videoUrl,
    this.episodeTitle,
    this.episodeNumber,
    this.animeTitle,
    this.introSkip,
    this.outroSkip,
    this.subtitles,
  });

  @override
  State<WebViewVideoPlayer> createState() => _WebViewVideoPlayerState();
}

class _WebViewVideoPlayerState extends State<WebViewVideoPlayer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // Set landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadHtmlString(_buildHtmlPlayer());
  }

  String _buildHtmlPlayer() {
    // Build skip buttons JavaScript
    String skipIntroJs = '';
    String skipOutroJs = '';
    String skipButtonsHtml = '';

    if (widget.introSkip != null) {
      final start = widget.introSkip!['start'] ?? 0;
      final end = widget.introSkip!['end'] ?? 0;
      skipIntroJs =
          '''
        var introStart = $start;
        var introEnd = $end;
        var skipIntroBtn = document.getElementById('skipIntro');
        video.addEventListener('timeupdate', function() {
          if (video.currentTime >= introStart && video.currentTime < introEnd) {
            skipIntroBtn.style.display = 'block';
          } else {
            skipIntroBtn.style.display = 'none';
          }
        });
        skipIntroBtn.addEventListener('click', function() {
          video.currentTime = introEnd;
        });
      ''';
      skipButtonsHtml +=
          '<button id="skipIntro" class="skip-btn" style="display:none;">Skip Intro</button>';
    }

    if (widget.outroSkip != null) {
      final start = widget.outroSkip!['start'] ?? 0;
      final end = widget.outroSkip!['end'] ?? 0;
      skipOutroJs =
          '''
        var outroStart = $start;
        var outroEnd = $end;
        var skipOutroBtn = document.getElementById('skipOutro');
        video.addEventListener('timeupdate', function() {
          if (video.currentTime >= outroStart && video.currentTime < outroEnd) {
            skipOutroBtn.style.display = 'block';
          } else {
            skipOutroBtn.style.display = 'none';
          }
        });
        skipOutroBtn.addEventListener('click', function() {
          video.currentTime = outroEnd;
        });
      ''';
      skipButtonsHtml +=
          '<button id="skipOutro" class="skip-btn" style="display:none;">Skip Outro</button>';
    }

    // Build subtitle tracks HTML and options
    String subtitleTracksHtml = '';
    String subtitleOptionsHtml = '<option value="-1">Off</option>';
    String subtitlesArrayJs = '[]';

    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      List<String> subsJson = [];
      int index = 0;
      for (final sub in widget.subtitles!) {
        final url = sub['url'] ?? '';
        final label = sub['label'] ?? 'Unknown';
        final kind = sub['kind'] ?? 'subtitles';
        final lang = sub['lang'] ?? 'en';

        // Add track element
        final defaultAttr = index == 0 ? 'default' : '';
        subtitleTracksHtml +=
            '<track kind="$kind" src="$url" srclang="$lang" label="$label" $defaultAttr>';

        // Add option for selector
        final selected = index == 0 ? 'selected' : '';
        subtitleOptionsHtml +=
            '<option value="$index" $selected>$label</option>';

        subsJson.add('{"url": "$url", "label": "$label"}');
        index++;
      }
      subtitlesArrayJs = '[${subsJson.join(',')}]';
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { 
      width: 100%; 
      height: 100%; 
      background: #000; 
      overflow: hidden;
    }
    .container {
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      position: relative;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      background: #000;
    }
    video::cue {
      background-color: rgba(0, 0, 0, 0.85);
      color: white;
      font-size: 20px;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.8);
    }
    .controls-overlay {
      position: absolute;
      bottom: 60px;
      left: 0;
      right: 0;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      padding: 0 20px;
      z-index: 100;
      pointer-events: none;
    }
    .controls-overlay > * {
      pointer-events: auto;
    }
    .subtitle-control {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .subtitle-control label {
      color: white;
      font-size: 12px;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    }
    .subtitle-control select {
      background: rgba(0, 0, 0, 0.85);
      color: white;
      border: 1px solid rgba(255, 215, 0, 0.6);
      padding: 8px 12px;
      border-radius: 6px;
      font-size: 13px;
      cursor: pointer;
      min-width: 120px;
    }
    .subtitle-control select:focus {
      outline: none;
      border-color: #FFD700;
    }
    .skip-buttons {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .skip-btn {
      background: rgba(200, 50, 50, 0.9);
      color: white;
      border: 1px solid rgba(255, 215, 0, 0.5);
      padding: 10px 20px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: bold;
      cursor: pointer;
    }
    .skip-btn:hover {
      background: rgba(200, 50, 50, 1);
    }
    .loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      z-index: 50;
    }
    .error {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: #ff6b6b;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      text-align: center;
      z-index: 50;
    }
    .cc-icon {
      width: 20px;
      height: 20px;
      fill: #FFD700;
    }
  </style>
</head>
<body>
  <div class="container">
    <video id="videoPlayer" controls playsinline crossorigin="anonymous">
      $subtitleTracksHtml
      Your browser does not support the video tag.
    </video>
    
    <div class="controls-overlay">
      <div class="subtitle-control">
        <svg class="cc-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path d="M19 4H5c-1.11 0-2 .9-2 2v12c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm-8 7H9.5v-.5h-2v3h2V13H11v1c0 .55-.45 1-1 1H7c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1zm7 0h-1.5v-.5h-2v3h2V13H18v1c0 .55-.45 1-1 1h-3c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1z"/>
        </svg>
        <select id="subtitleSelect" onchange="changeSubtitle(this.value)">
          $subtitleOptionsHtml
        </select>
      </div>
      <div class="skip-buttons">
        $skipButtonsHtml
      </div>
    </div>
    
    <div id="loading" class="loading">Loading video...</div>
    <div id="error" class="error" style="display:none;">
      <p>Failed to load video</p>
      <p style="font-size: 12px; margin-top: 10px;">Please try a different server</p>
    </div>
  </div>
  <script>
    var video = document.getElementById('videoPlayer');
    var loading = document.getElementById('loading');
    var error = document.getElementById('error');
    var subtitles = $subtitlesArrayJs;
    var videoSrc = '${widget.videoUrl}';
    
    // Initialize HLS.js for Android/browsers that don't support HLS natively
    function initPlayer() {
      if (Hls.isSupported()) {
        console.log('Using HLS.js');
        var hls = new Hls({
          enableWorker: true,
          lowLatencyMode: false,
          backBufferLength: 90
        });
        hls.loadSource(videoSrc);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, function() {
          console.log('Manifest parsed, starting playback');
          loading.style.display = 'none';
          video.play().catch(function(e) {
            console.log('Autoplay failed:', e);
          });
        });
        hls.on(Hls.Events.ERROR, function(event, data) {
          console.log('HLS error:', data.type, data.details);
          if (data.fatal) {
            switch(data.type) {
              case Hls.ErrorTypes.NETWORK_ERROR:
                console.log('Network error, trying to recover...');
                hls.startLoad();
                break;
              case Hls.ErrorTypes.MEDIA_ERROR:
                console.log('Media error, trying to recover...');
                hls.recoverMediaError();
                break;
              default:
                console.log('Fatal error, cannot recover');
                loading.style.display = 'none';
                error.style.display = 'block';
                video.style.display = 'none';
                hls.destroy();
                break;
            }
          }
        });
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        // Native HLS support (Safari/iOS)
        console.log('Using native HLS');
        video.src = videoSrc;
        video.addEventListener('loadedmetadata', function() {
          loading.style.display = 'none';
          video.play().catch(function(e) {
            console.log('Autoplay failed:', e);
          });
        });
      } else {
        console.log('HLS not supported');
        loading.style.display = 'none';
        error.style.display = 'block';
        error.innerHTML = '<p>HLS not supported on this device</p>';
      }
    }
    
    // Wait for HLS.js to load then init
    if (typeof Hls !== 'undefined') {
      initPlayer();
    } else {
      // HLS.js not loaded yet, wait a bit
      setTimeout(function() {
        if (typeof Hls !== 'undefined') {
          initPlayer();
        } else {
          loading.style.display = 'none';
          error.style.display = 'block';
          error.innerHTML = '<p>Failed to load video player</p>';
        }
      }, 2000);
    }
    
    // Subtitle handling
    function changeSubtitle(index) {
      var tracks = video.textTracks;
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].mode = (i == index) ? 'showing' : 'hidden';
      }
    }
    
    // Enable first subtitle by default
    video.addEventListener('loadedmetadata', function() {
      var tracks = video.textTracks;
      if (tracks.length > 0) {
        for (var i = 0; i < tracks.length; i++) {
          tracks[i].mode = (i == 0) ? 'showing' : 'hidden';
        }
      }
    });
    
    video.addEventListener('error', function(e) {
      console.log('Video error:', e);
      loading.style.display = 'none';
      error.style.display = 'block';
      video.style.display = 'none';
    });
    
    $skipIntroJs
    $skipOutroJs
  </script>
</body>
</html>
''';
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // WebView Player
            WebViewWidget(controller: _controller),

            // Top Bar
            Positioned(
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
                      onPressed: () => Navigator.pop(context),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(179),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.web, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'WebView',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    OnePieceTheme.strawHatRed,
                  ),
                ),
              ),

            // Error indicator
            if (_hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: OnePieceTheme.strawHatRed,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load video',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isLoading = true;
                        });
                        _controller.reload();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OnePieceTheme.strawHatRed,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
