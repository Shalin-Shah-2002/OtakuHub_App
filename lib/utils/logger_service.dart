import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Log levels for categorizing log messages
enum LogLevel { verbose, debug, info, warning, error, fatal }

/// A log entry that captures all relevant information
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? extras;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
    this.extras,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name.toUpperCase(),
    'tag': tag,
    'message': message,
    if (error != null) 'error': error.toString(),
    if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    if (extras != null) 'extras': extras,
  };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    buffer.write('[$tag] ');
    buffer.write(message);
    if (error != null) {
      buffer.write('\n  Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  StackTrace: $stackTrace');
    }
    if (extras != null && extras!.isNotEmpty) {
      buffer.write('\n  Extras: ${jsonEncode(extras)}');
    }
    return buffer.toString();
  }
}

/// Singleton Logger Service for comprehensive app-wide logging
class LoggerService {
  static LoggerService? _instance;
  static LoggerService get instance => _instance ??= LoggerService._();

  LoggerService._();

  // Configuration
  LogLevel _minLevel = kDebugMode ? LogLevel.verbose : LogLevel.info;
  bool _enableConsoleOutput = true;
  // ignore: unused_field
  bool _enableFileLogging = false; // Reserved for future file logging
  int _maxLogHistory = 1000;

  // Log history for in-app viewing
  final List<LogEntry> _logHistory = [];
  List<LogEntry> get logHistory => List.unmodifiable(_logHistory);

  // Stream for real-time log monitoring
  final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get logStream => _logStreamController.stream;

  // Error tracking
  final List<LogEntry> _errorHistory = [];
  List<LogEntry> get errorHistory => List.unmodifiable(_errorHistory);
  int _errorCount = 0;
  int get errorCount => _errorCount;

  // Performance tracking
  final Map<String, Stopwatch> _performanceTrackers = {};

  /// Configure the logger
  void configure({
    LogLevel? minLevel,
    bool? enableConsoleOutput,
    bool? enableFileLogging,
    int? maxLogHistory,
  }) {
    if (minLevel != null) _minLevel = minLevel;
    if (enableConsoleOutput != null) _enableConsoleOutput = enableConsoleOutput;
    if (enableFileLogging != null) _enableFileLogging = enableFileLogging;
    if (maxLogHistory != null) _maxLogHistory = maxLogHistory;
  }

  /// Core logging method
  void _log(
    LogLevel level,
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) {
    if (level.index < _minLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extras: extras,
    );

    // Add to history
    _logHistory.add(entry);
    if (_logHistory.length > _maxLogHistory) {
      _logHistory.removeAt(0);
    }

    // Track errors separately
    if (level == LogLevel.error || level == LogLevel.fatal) {
      _errorCount++;
      _errorHistory.add(entry);
      if (_errorHistory.length > 100) {
        _errorHistory.removeAt(0);
      }
    }

    // Emit to stream
    _logStreamController.add(entry);

    // Console output
    if (_enableConsoleOutput) {
      _printToConsole(entry);
    }
  }

  /// Print formatted log to console with colors
  void _printToConsole(LogEntry entry) {
    final emoji = _getEmoji(entry.level);
    final color = _getAnsiColor(entry.level);
    final reset = '\x1B[0m';

    if (kDebugMode) {
      final output = StringBuffer();
      output.write('$color$emoji ');
      output.write('[${_formatTime(entry.timestamp)}] ');
      output.write('[${entry.tag}] ');
      output.write(entry.message);
      output.write(reset);

      debugPrint(output.toString());

      if (entry.error != null) {
        debugPrint(
          '$color   ╔══ ERROR ══════════════════════════════════════$reset',
        );
        debugPrint('$color   ║ ${entry.error}$reset');
        debugPrint(
          '$color   ╚════════════════════════════════════════════════$reset',
        );
      }

      if (entry.stackTrace != null) {
        debugPrint('$color   StackTrace:$reset');
        final lines = entry.stackTrace.toString().split('\n').take(10);
        for (final line in lines) {
          debugPrint('$color   │ $line$reset');
        }
      }

      if (entry.extras != null && entry.extras!.isNotEmpty) {
        debugPrint('$color   Extras: ${jsonEncode(entry.extras)}$reset');
      }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return '📝';
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return '💡';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.fatal:
        return '💀';
    }
  }

  String _getAnsiColor(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return '\x1B[37m'; // White
      case LogLevel.debug:
        return '\x1B[36m'; // Cyan
      case LogLevel.info:
        return '\x1B[32m'; // Green
      case LogLevel.warning:
        return '\x1B[33m'; // Yellow
      case LogLevel.error:
        return '\x1B[31m'; // Red
      case LogLevel.fatal:
        return '\x1B[35m'; // Magenta
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PUBLIC LOGGING METHODS
  // ════════════════════════════════════════════════════════════════════════════

  /// Log verbose message (most detailed)
  void v(String tag, String message, {Map<String, dynamic>? extras}) {
    _log(LogLevel.verbose, tag, message, extras: extras);
  }

  /// Log debug message
  void d(String tag, String message, {Map<String, dynamic>? extras}) {
    _log(LogLevel.debug, tag, message, extras: extras);
  }

  /// Log info message
  void i(String tag, String message, {Map<String, dynamic>? extras}) {
    _log(LogLevel.info, tag, message, extras: extras);
  }

  /// Log warning message
  void w(
    String tag,
    String message, {
    dynamic error,
    Map<String, dynamic>? extras,
  }) {
    _log(LogLevel.warning, tag, message, error: error, extras: extras);
  }

  /// Log error message
  void e(
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) {
    _log(
      LogLevel.error,
      tag,
      message,
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      extras: extras,
    );
  }

  /// Log fatal error message
  void f(
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) {
    _log(
      LogLevel.fatal,
      tag,
      message,
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      extras: extras,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SPECIALIZED LOGGING METHODS
  // ════════════════════════════════════════════════════════════════════════════

  /// Log API request
  void logApiRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    _log(
      LogLevel.info,
      'API',
      '→ $method $url',
      extras: {
        'type': 'request',
        'method': method,
        'url': url,
        if (headers != null) 'headers': headers,
        if (body != null) 'body': body,
      },
    );
  }

  /// Log API response
  void logApiResponse({
    required String method,
    required String url,
    required int statusCode,
    dynamic body,
    int? durationMs,
  }) {
    final isSuccess = statusCode >= 200 && statusCode < 300;
    _log(
      isSuccess ? LogLevel.info : LogLevel.error,
      'API',
      '← $method $url [$statusCode] ${durationMs != null ? '(${durationMs}ms)' : ''}',
      extras: {
        'type': 'response',
        'method': method,
        'url': url,
        'statusCode': statusCode,
        if (durationMs != null) 'durationMs': durationMs,
        if (body != null && !isSuccess) 'body': body,
      },
    );
  }

  /// Log API error
  void logApiError({
    required String method,
    required String url,
    required dynamic error,
    StackTrace? stackTrace,
    int? durationMs,
  }) {
    _log(
      LogLevel.error,
      'API',
      '✗ $method $url FAILED ${durationMs != null ? '(${durationMs}ms)' : ''}',
      error: error,
      stackTrace: stackTrace,
      extras: {
        'type': 'api_error',
        'method': method,
        'url': url,
        if (durationMs != null) 'durationMs': durationMs,
      },
    );
  }

  /// Log navigation event
  void logNavigation(String from, String to, {Map<String, dynamic>? params}) {
    _log(
      LogLevel.info,
      'NAV',
      '$from → $to',
      extras: {'from': from, 'to': to, if (params != null) 'params': params},
    );
  }

  /// Log user action
  void logUserAction(String action, {Map<String, dynamic>? details}) {
    _log(LogLevel.info, 'USER', action, extras: details);
  }

  /// Log state change
  void logStateChange(String controller, String state, {dynamic value}) {
    _log(
      LogLevel.debug,
      'STATE',
      '$controller.$state changed',
      extras: {
        'controller': controller,
        'state': state,
        if (value != null) 'value': value.toString(),
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PERFORMANCE TRACKING
  // ════════════════════════════════════════════════════════════════════════════

  /// Start a performance timer
  void startTimer(String name) {
    _performanceTrackers[name] = Stopwatch()..start();
    _log(LogLevel.debug, 'PERF', '⏱️ Started: $name');
  }

  /// Stop a performance timer and log the duration
  int? stopTimer(String name) {
    final stopwatch = _performanceTrackers.remove(name);
    if (stopwatch != null) {
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      _log(
        ms > 1000 ? LogLevel.warning : LogLevel.debug,
        'PERF',
        '⏱️ $name completed in ${ms}ms',
        extras: {'name': name, 'durationMs': ms},
      );
      return ms;
    }
    return null;
  }

  /// Measure async operation performance
  Future<T> measureAsync<T>(String name, Future<T> Function() operation) async {
    startTimer(name);
    try {
      final result = await operation();
      stopTimer(name);
      return result;
    } catch (e) {
      stopTimer(name);
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ════════════════════════════════════════════════════════════════════════════

  /// Clear all log history
  void clearHistory() {
    _logHistory.clear();
    _errorHistory.clear();
    _errorCount = 0;
  }

  /// Get logs filtered by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logHistory.where((entry) => entry.level == level).toList();
  }

  /// Get logs filtered by tag
  List<LogEntry> getLogsByTag(String tag) {
    return _logHistory.where((entry) => entry.tag == tag).toList();
  }

  /// Export logs as JSON
  String exportLogsAsJson() {
    return jsonEncode(_logHistory.map((e) => e.toJson()).toList());
  }

  /// Get error summary
  Map<String, dynamic> getErrorSummary() {
    return {
      'totalErrors': _errorCount,
      'recentErrors': _errorHistory.take(10).map((e) => e.toJson()).toList(),
      'errorsByTag': _groupErrorsByTag(),
    };
  }

  Map<String, int> _groupErrorsByTag() {
    final grouped = <String, int>{};
    for (final entry in _errorHistory) {
      grouped[entry.tag] = (grouped[entry.tag] ?? 0) + 1;
    }
    return grouped;
  }

  /// Dispose resources
  void dispose() {
    _logStreamController.close();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GLOBAL SHORTCUT
// ════════════════════════════════════════════════════════════════════════════

/// Global logger instance for easy access
final logger = LoggerService.instance;

// ════════════════════════════════════════════════════════════════════════════
// FLUTTER ERROR HANDLER
// ════════════════════════════════════════════════════════════════════════════

/// Setup global Flutter error handling
void setupGlobalErrorHandling() {
  // Handle Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.f(
      'FLUTTER',
      'Flutter Framework Error',
      error: details.exception,
      stackTrace: details.stack,
      extras: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );

    // In debug mode, also print the default Flutter error
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  // Handle errors outside of Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.f(
      'PLATFORM',
      'Uncaught Platform Error',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
}
