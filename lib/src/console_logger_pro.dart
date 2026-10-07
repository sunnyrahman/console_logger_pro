import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'console_json_formatter.dart';
import 'http_capture_stub.dart' if (dart.library.io) 'http_capture_io.dart';
import 'log_color.dart';
import 'log_theme.dart';

/// Receives one console line at a time.
typedef LogPrinter = void Function(String line);

/// Clean, professional and colorized API logger for the Flutter console.
///
/// Designed to pub.dev standards with minimal, elegant typography and zero
/// emoji clutter:
///
/// * Endpoint: Cyan
/// * Success (2xx/3xx): Green
/// * Error (4xx/5xx): Red
/// * Response payload: Gold / Yellow
/// * Request payload: Pink / Magenta
/// * Query parameters: Blue
/// * Security tokens: Yellow
/// * User data: Purple / Magenta
/// * General logs: Crisp White
///
/// ```dart
/// void main() {
///   ConsoleLoggerPro.install(); // Captures Dio, http and dart:io automatically
///   runApp(const MyApp());
/// }
/// ```
class ConsoleLoggerPro {
  ConsoleLoggerPro({
    this.theme = const LogTheme(),
    bool? enabled,
    this.showRequestHeaders = false,
    this.showResponseHeaders = false,
    this.showTokens = true,
    this.repeatTokens = true,
    this.autoCopyToken = true,
    this.lineGap = 3,
    this.maxLines = 300,
    this.lineWidth = 80,
    LogPrinter? printer,
  })  : enabled = enabled ?? kDebugMode,
        _printer = printer ?? _defaultPrinter;

  /// Colors of each section.
  final LogTheme theme;

  /// Logs nothing when `false`. Defaults to [kDebugMode].
  final bool enabled;

  /// Print request headers (tokens in them are still detected when `false`).
  final bool showRequestHeaders;

  /// Print response headers.
  final bool showResponseHeaders;

  /// Print the 🔑 Tokens section (each token alone on a line, easy to copy).
  final bool showTokens;

  /// When `true` (default), tokens are always printed in full so they can be
  /// copied directly from any request in the console. When `false`, tokens
  /// already printed once are shortened to avoid repetition.
  final bool repeatTokens;

  /// When `true` (default), newly detected security tokens are automatically
  /// copied to the system clipboard for zero-click pasting in Postman, etc.
  final bool autoCopyToken;

  /// Number of blank lines printed after each API log block for clear separation.
  /// Defaults to 3.
  final int lineGap;

  /// Maximum lines per section before truncation.
  final int maxLines;

  /// Width of the box framing lines.
  final int lineWidth;

  final LogPrinter _printer;
  final Set<String> _shownTokens = <String>{};

  static void _defaultPrinter(String line) {
    developer.log(line, name: '');
  }

  // ---------------------------------------------------------------------------
  // Static API
  // ---------------------------------------------------------------------------

  static ConsoleLoggerPro? _shared;

  /// The logger used by [log], [userData] and [install].
  static ConsoleLoggerPro get shared => _shared ??= ConsoleLoggerPro();
  static set shared(ConsoleLoggerPro logger) => _shared = logger;

  /// Logs every HTTP request made with `http`, Dio or `dart:io`.
  /// Call once, before `runApp`:
  ///
  /// ```dart
  /// void main() {
  ///   ConsoleLoggerPro.install();
  ///   runApp(const MyApp());
  /// }
  /// ```
  static void install({
    ConsoleLoggerPro? logger,
    bool Function(Uri uri)? filter,
    bool logBinary = false,
    int maxBodyBytes = 1024 * 1024,
  }) {
    final target = logger ?? shared;
    _shared = target;
    if (!target.enabled) return;
    installHttpCapture(
      logger: target,
      filter: filter,
      logBinary: logBinary,
      maxBodyBytes: maxBodyBytes,
    );
  }

  /// Stops automatic capture started by [install].
  static void uninstall() => uninstallHttpCapture();

  /// Prints a general console message with clean `[LOG]` tag.
  static void log(Object? message, {Object? data}) =>
      shared.logMessage(message, data: data);

  /// Prints data submitted from UI / form inputs with clean `[USER DATA]` tag.
  static void userData(String title, Object? data) =>
      shared.logUserData(title, data);

  // ---------------------------------------------------------------------------
  // Instance API
  // ---------------------------------------------------------------------------

  /// Logs a complete API transaction (request + response or error) in a unified box.
  void logApi({
    required String method,
    required String url,
    int? statusCode,
    String? statusMessage,
    Map<String, dynamic>? requestHeaders,
    Object? requestBody,
    String? requestBodyType,
    Map<String, dynamic>? responseHeaders,
    Object? responseBody,
    Object? error,
    StackTrace? stackTrace,
    Duration? duration,
  }) {
    if (!enabled) return;
    final tokens = <DetectedToken>[];
    final box = _Box(this)..top();
    box.row(_endpointLine(method, url));
    final failed = error != null || (statusCode != null && statusCode >= 400);
    if (statusCode != null || error != null) {
      box.row(_statusLine(statusCode, statusMessage, duration, failed));
    }
    _writeRequest(
        box, url, requestHeaders, requestBody, requestBodyType, tokens);
    if (showResponseHeaders &&
        responseHeaders != null &&
        responseHeaders.isNotEmpty) {
      _section(box, 'Response Headers', responseHeaders, theme.key, tokens);
    }
    if (responseBody != null && responseBody != '') {
      _section(
          box, 'Response', _normalize(responseBody), theme.response, tokens);
    }
    if (error != null) _writeError(box, error, stackTrace);
    _writeTokens(box, tokens);
    box
      ..bottom()
      ..flush();
  }

  /// Logs an outgoing request on its own (manual usage).
  void logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Object? body,
  }) {
    if (!enabled) return;
    final tokens = <DetectedToken>[];
    final box = _Box(this)..top();
    box.row(
        '${_endpointLine(method, url)}  ${theme.paint(theme.border, '[SENDING]')}');
    _writeRequest(box, url, headers, body, null, tokens);
    _writeTokens(box, tokens);
    box
      ..bottom()
      ..flush();
  }

  /// Logs a received response (manual usage).
  void logResponse({
    required String method,
    required String url,
    required int statusCode,
    String? statusMessage,
    Map<String, dynamic>? headers,
    Object? body,
    Duration? duration,
  }) =>
      logApi(
        method: method,
        url: url,
        statusCode: statusCode,
        statusMessage: statusMessage,
        responseHeaders: headers,
        responseBody: body,
        duration: duration,
      );

  /// Logs a failed request (manual usage).
  void logError({
    required String method,
    required String url,
    Object? error,
    StackTrace? stackTrace,
    int? statusCode,
    Object? body,
    Duration? duration,
  }) =>
      logApi(
        method: method,
        url: url,
        statusCode: statusCode,
        responseBody: body,
        error: error ?? 'Request failed',
        stackTrace: stackTrace,
        duration: duration,
      );

  /// Instance version of [log].
  void logMessage(Object? message, {Object? data}) {
    if (!enabled) return;
    final head = '${theme.paint(theme.log, '[LOG]', bold: true)}  '
        '${theme.paint(theme.log, '$message')}';
    if (data == null) {
      _printer(head);
      return;
    }
    final box = _Box(this)..top();
    box.row(head);
    box.block(_render(data, theme.log, <DetectedToken>[]));
    box
      ..bottom()
      ..flush();
  }

  /// Instance version of [userData].
  void logUserData(String title, Object? data) {
    if (!enabled) return;
    final box = _Box(this)..top();
    box.row('${theme.paint(theme.userData, '[USER DATA]', bold: true)}  '
        '${theme.paint(theme.userData, title)}');
    if (data != null) {
      box.divider();
      box.block(_render(_normalize(data), theme.userData, <DetectedToken>[]));
    }
    box
      ..bottom()
      ..flush();
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  String _endpointLine(String method, String url) {
    final q = url.indexOf('?');
    final path = q < 0 ? url : url.substring(0, q);
    final mColor = theme.methodColor(method);
    return '${theme.paint(mColor, '[${method.toUpperCase()}]', bold: true)}  '
        '${theme.paint(theme.endpoint, path)}';
  }

  String _statusLine(
      int? statusCode, String? statusMessage, Duration? duration, bool failed) {
    final color = failed ? theme.error : theme.success;
    final label = statusCode == null
        ? 'FAILED'
        : '$statusCode ${statusMessage ?? ''}'.trim();
    final time = duration == null ? '' : '  ·  ${duration.inMilliseconds} ms';
    return '${theme.paint(color, '[$label]', bold: true)}'
        '${theme.paint(theme.border, time)}';
  }

  void _writeRequest(
    _Box box,
    String url,
    Map<String, dynamic>? headers,
    Object? body,
    String? bodyType,
    List<DetectedToken> tokens,
  ) {
    final params = _queryOf(url);
    if (params.isNotEmpty) {
      _section(box, 'Params', params, theme.params, tokens);
    }
    if (headers != null && headers.isNotEmpty) {
      if (showRequestHeaders) {
        _section(box, 'Headers', headers, theme.key, tokens);
      } else {
        _render(headers, theme.key, tokens); // only to detect tokens
      }
    }
    if (body != null && body != '') {
      final title = bodyType == null ? 'Body' : 'Body ($bodyType)';
      _section(box, title, _normalize(body), theme.body, tokens);
    }
  }

  void _writeError(_Box box, Object error, StackTrace? stackTrace) {
    box.section('Error', theme.error);
    for (final l in '$error'.split('\n')) {
      box.row(theme.paint(theme.error, l));
    }
    if (stackTrace != null) {
      final frames = stackTrace
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(5);
      for (final f in frames) {
        box.row(theme.paint(theme.border, f.trim()));
      }
    }
  }

  void _writeTokens(_Box box, List<DetectedToken> tokens) {
    if (!showTokens || tokens.isEmpty) return;
    if (autoCopyToken && tokens.isNotEmpty) {
      try {
        Clipboard.setData(ClipboardData(text: tokens.first.value))
            .catchError((_) {});
      } catch (_) {}
    }
    final hint =
        autoCopyToken ? 'Copied to clipboard!' : 'triple-click line to copy';
    box.section('Tokens', theme.token, hint: hint);
    for (final t in tokens) {
      final seen = !repeatTokens && !_shownTokens.add(t.value);
      if (seen) {
        box.row('${theme.paint(theme.border, '${t.label}: ')}'
            '${theme.paint(theme.token, _shorten(t.value))} '
            '${theme.paint(theme.border, '(shown earlier)')}');
      } else {
        box.row('${theme.paint(theme.border, '${t.label}: ')}'
            '${theme.paint(theme.token, t.value)}');
      }
    }
  }

  void _section(
    _Box box,
    String title,
    Object? data,
    LogColor color,
    List<DetectedToken> tokens,
  ) {
    box.section(title, color);
    box.block(_render(data, color, tokens));
  }

  String _render(Object? data, LogColor color, List<DetectedToken> tokens) {
    final f = ConsoleJsonFormatter(theme);
    final text = f.format(data, color: color);
    for (final t in f.tokens) {
      if (!tokens.any((x) => x.value == t.value)) tokens.add(t);
    }
    return text;
  }

  static String _shorten(String token) => token.length <= 24
      ? token
      : '${token.substring(0, 10)}…${token.substring(token.length - 6)}';

  static Map<String, Object?> _queryOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasQuery) return const {};
    try {
      return uri.queryParametersAll
          .map((k, v) => MapEntry(k, v.length == 1 ? v.first : v));
    } catch (_) {
      return {'query': uri.query};
    }
  }

  static Object? _normalize(Object? body) {
    if (body is String) {
      final s = body.trimLeft();
      if (s.startsWith('{') || s.startsWith('[')) {
        try {
          return jsonDecode(body);
        } catch (_) {}
      }
    }
    return body;
  }
}

/// Collects the lines of one box and prints them together.
class _Box {
  _Box(this._logger);

  final ConsoleLoggerPro _logger;
  final List<String> _lines = <String>[];

  LogTheme get _t => _logger.theme;
  String _b(String s) => _t.paint(_t.border, s);
  String get _bar => '─' * _logger.lineWidth;

  void top() => _lines.add(_b('┌$_bar'));
  void bottom() => _lines.add(_b('└$_bar'));
  void divider() => _lines.add(_b('├$_bar'));
  void row(String text) => _lines.add('${_b('│')} $text');
  void raw(String text) => _lines.add(text);

  void section(String title, LogColor color, {String? hint}) {
    final h = hint == null ? '' : '  ${_b('($hint)')}';
    _lines.add('${_b('├─')} ${_t.paint(color, '[$title]', bold: true)}$h');
  }

  void block(String text) {
    var lines = text.split('\n');
    var hidden = 0;
    if (lines.length > _logger.maxLines) {
      hidden = lines.length - _logger.maxLines;
      lines = lines.sublist(0, _logger.maxLines);
    }
    for (final l in lines) {
      row('  $l');
    }
    if (hidden > 0) row(_b('  … $hidden more lines hidden'));
  }

  void flush() {
    final buffer = StringBuffer();
    for (final line in _lines) {
      buffer.writeln(line);
    }
    for (var i = 0; i < _logger.lineGap; i++) {
      buffer.writeln('\u2800' * (i + 1));
    }
    _logger._printer(buffer.toString().trimRight());
  }
}
