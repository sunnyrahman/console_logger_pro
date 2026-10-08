import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_call_record.dart';
import 'console_json_formatter.dart';
import 'http_capture_stub.dart' if (dart.library.io) 'http_capture_io.dart';
import 'log_color.dart';
import 'log_theme.dart';
import 'ui/console_inspector_sheet.dart';

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
    this.showRequestHeaders = true,
    this.showResponseHeaders = false,
    this.showTokens = true,
    this.repeatTokens = true,
    this.autoCopyToken = true,
    this.lineGap = 3,
    this.maxLines = 300,
    this.lineWidth = 80,
    this.collapseDepth,
    this.maxArrayItems,
    this.collapseKeys = const <String>[],
    this.collapseListItems = false,
    this.collapsePredicate,
    this.maxHistoryLength = 50,
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

  /// If non-null, JSON objects/arrays at nesting depth >= [collapseDepth]
  /// are printed in collapsed format: `{...}` or `[...]`.
  final int? collapseDepth;

  /// Maximum items to print per array. Items beyond this count are collapsed
  /// into comments like `// ... (N more items)`.
  final int? maxArrayItems;

  /// Specific JSON keys whose values should be printed in collapsed format `{...}` or `[...]`.
  final List<String> collapseKeys;

  /// When `true`, objects inside arrays are collapsed into `{...}` like in Postman.
  final bool collapseListItems;

  /// Custom predicate to decide whether a value should be collapsed.
  final bool Function(String? key, int level, Object? value)? collapsePredicate;

  /// Maximum number of recent network call records retained in memory for in-app inspection.
  final int maxHistoryLength;

  /// In-memory ring buffer of recent network calls captured by this logger.
  final List<ApiCallRecord> records = <ApiCallRecord>[];

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

  /// In-memory history of recent API network calls captured by this logger.
  static List<ApiCallRecord> get history => shared.records;

  /// Clears in-memory history of captured network calls.
  static void clearHistory() => shared.clearRecords();

  /// Displays the interactive In-App Network Inspector modal sheet.
  ///
  /// Every request/response JSON has real clickable bracket-to-bracket
  /// collapse/expand (`{...}` and `[...]`) like Postman!
  static Future<void> showInspector(BuildContext context) =>
      ConsoleInspectorSheet.show(
        context,
        records: shared.records,
        onClear: clearHistory,
      );

  /// Displays an interactive Postman-style collapsible JSON tree dialog for any [data].
  static Future<void> showJsonViewer(
    BuildContext context, {
    required Object? data,
    String title = 'JSON Viewer',
  }) =>
      ConsoleInspectorSheet.showJson(
        context,
        data: data,
        title: title,
      );

  /// Clears in-memory history of captured calls for this instance.
  void clearRecords() => records.clear();

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
    int? collapseDepth,
    int? maxArrayItems,
    List<String>? collapseKeys,
    bool? collapseListItems,
    bool Function(String? key, int level, Object? value)? collapsePredicate,
    int maxHistoryLength = 50,
  }) {
    final target = logger ??
        (collapseDepth != null ||
                maxArrayItems != null ||
                collapseKeys != null ||
                collapseListItems != null ||
                collapsePredicate != null ||
                maxHistoryLength != 50
            ? ConsoleLoggerPro(
                collapseDepth: collapseDepth,
                maxArrayItems: maxArrayItems,
                collapseKeys: collapseKeys ?? const <String>[],
                collapseListItems: collapseListItems ?? false,
                collapsePredicate: collapsePredicate,
                maxHistoryLength: maxHistoryLength,
              )
            : shared);
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

  /// Logs a UI click or tap interaction event with styled [ON CLICK] badge.
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () {
  ///     ConsoleLoggerPro.click('Login button pressed', data: {'email': email});
  ///   },
  ///   child: const Text('Login'),
  /// )
  /// ```
  static void click(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logClick(message, data: data, tag: tag, boxed: boxed);

  /// Alias for [click].
  static void onClick(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logClick(message, data: data, tag: tag, boxed: boxed);

  /// Logs a debug inspection or state check with styled [DEBUG] badge.
  ///
  /// ```dart
  /// ConsoleLoggerPro.debug('User profile loaded', data: user.toJson());
  /// ```
  static void debug(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logDebug(message, data: data, tag: tag, boxed: boxed);

  /// Direct replacement for standard `print()`, wrapped in a clean, colorized box.
  ///
  /// ```dart
  /// ConsoleLoggerPro.print('Screen navigated: /dashboard');
  /// ```
  static void print(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logPrint(message, data: data, tag: tag, boxed: boxed);

  /// Prints an informational message with styled [INFO] badge.
  static void info(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logInfo(message, data: data, tag: tag, boxed: boxed);

  /// Prints a warning message with styled [WARNING] badge.
  static void warning(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logWarning(message, data: data, tag: tag, boxed: boxed);

  /// Alias for [warning].
  static void warn(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logWarning(message, data: data, tag: tag, boxed: boxed);

  /// Prints an error message with styled [ERROR] badge, error details, and stack trace.
  static void error(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Object? data,
    String? tag,
  }) =>
      shared.logException(
        message,
        error: error,
        stackTrace: stackTrace,
        data: data,
        tag: tag,
      );

  /// Prints a general console message with styled [LOG] tag.
  static void log(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) =>
      shared.logMessage(message, data: data, tag: tag, boxed: boxed);

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
    if (maxHistoryLength > 0) {
      if (records.length >= maxHistoryLength) records.removeAt(0);
      records.add(ApiCallRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        method: method,
        url: url,
        statusCode: statusCode,
        statusMessage: statusMessage,
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        requestBodyType: requestBodyType,
        responseHeaders: responseHeaders,
        responseBody: responseBody,
        error: error,
        stackTrace: stackTrace,
        duration: duration,
      ));
    }
    final tokens = <DetectedToken>[];
    final box = _Box(this)..top();
    box.row(_endpointLine(method, url));
    final failed = error != null || (statusCode != null && statusCode >= 400);
    if (statusCode != null || error != null) {
      box.row(_statusLine(statusCode, statusMessage, duration, failed));
    }
    _writeRequest(
      box,
      url,
      requestHeaders,
      requestBody,
      requestBodyType,
      tokens,
      failed: failed,
    );
    if (showResponseHeaders &&
        responseHeaders != null &&
        responseHeaders.isNotEmpty) {
      _section(box, 'Response Headers', responseHeaders, theme.responseHeader,
          tokens);
    }
    if (responseBody != null && responseBody != '') {
      // Two blank spacer rows before Response for visual separation
      box.row('');
      box.row('');
      final responseHint = _buildResponseHint(statusCode, statusMessage, failed);
      _section(
        box,
        'Response',
        _normalize(responseBody),
        theme.response,
        tokens,
        hint: responseHint,
      );
    }
    if (error != null) {
      box.row('');
      box.row('');
      _writeError(box, error, stackTrace);
    }
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

  /// Logs a UI click or tap interaction.
  void logClick(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) {
    _logSection(
      badge: tag ?? 'ON CLICK',
      badgeColor: theme.click,
      message: message,
      data: data,
      dataSectionTitle: 'Event Data',
      boxed: boxed,
    );
  }

  /// Logs a debug state or variable inspection.
  void logDebug(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) {
    _logSection(
      badge: tag ?? 'DEBUG',
      badgeColor: theme.debug,
      message: message,
      data: data,
      dataSectionTitle: 'Debug Data',
      boxed: boxed,
    );
  }

  /// Formats and logs a custom message (replaces standard print).
  void logPrint(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) {
    _logSection(
      badge: tag ?? 'PRINT',
      badgeColor: theme.log,
      message: message,
      data: data,
      boxed: boxed,
    );
  }

  /// Logs an informational message.
  void logInfo(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) {
    _logSection(
      badge: tag ?? 'INFO',
      badgeColor: theme.info,
      message: message,
      data: data,
      boxed: boxed,
    );
  }

  /// Logs a warning message.
  void logWarning(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) {
    _logSection(
      badge: tag ?? 'WARNING',
      badgeColor: theme.warning,
      message: message,
      data: data,
      boxed: boxed,
    );
  }

  /// Logs an application exception or error with stack trace.
  void logException(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Object? data,
    String? tag,
  }) {
    _logSection(
      badge: tag ?? 'ERROR',
      badgeColor: theme.error,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
      boxed: true,
    );
  }

  /// Instance version of [log].
  void logMessage(
    Object? message, {
    Object? data,
    String? tag,
    bool boxed = true,
  }) {
    _logSection(
      badge: tag ?? 'LOG',
      badgeColor: theme.log,
      message: message,
      data: data,
      boxed: boxed,
    );
  }

  /// Instance version of [userData].
  void logUserData(String title, Object? data) {
    if (!enabled) return;
    final box = _Box(this, gap: 1)..top();
    box.row('${theme.paint(theme.userData, '[USER DATA]', bold: true)}  '
        '${theme.paint(theme.userData, title)}');
    if (data != null) {
      box.section('Form Data', theme.userData);
      box.block(_render(_normalize(data), theme.userData, <DetectedToken>[]));
    }
    box
      ..bottom()
      ..flush();
  }

  void _logSection({
    required String badge,
    required LogColor badgeColor,
    required Object? message,
    Object? data,
    String? dataSectionTitle,
    Object? error,
    StackTrace? stackTrace,
    bool boxed = true,
  }) {
    if (!enabled) return;
    final badgeText = theme.paint(badgeColor, '[$badge]', bold: true);
    final msgText =
        message == null ? '' : '  ${theme.paint(badgeColor, '$message')}';
    final head = '$badgeText$msgText';

    if (!boxed && data == null && error == null) {
      _printer(head);
      return;
    }

    final box = _Box(this, gap: 1)..top();
    box.row(head);

    if (data != null) {
      final sectionTitle = dataSectionTitle ?? 'Data';
      box.section(sectionTitle, badgeColor);
      box.block(_render(_normalize(data), badgeColor, <DetectedToken>[]));
    }

    if (error != null) {
      _writeError(box, error, stackTrace);
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
    List<DetectedToken> tokens, {
    bool failed = false,
  }) {
    final params = _queryOf(url);
    if (params.isNotEmpty) {
      _section(box, 'Request Params', params, theme.params, tokens);
    }
    final shouldShowHeaders = showRequestHeaders || failed;
    if (headers != null && headers.isNotEmpty) {
      if (shouldShowHeaders) {
        _section(box, 'Request Headers', headers, theme.requestHeader, tokens);
      } else {
        _render(headers, theme.requestHeader, tokens); // only to detect tokens
      }
    }
    if (body != null && body != '') {
      final title =
          bodyType == null ? 'Request Body' : 'Request Body ($bodyType)';
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
    List<DetectedToken> tokens, {
    String? hint,
  }) {
    box.section(title, color, hint: hint);
    box.block(_render(data, color, tokens));
  }

  /// Builds a human-readable hint label for the Response section.
  /// e.g. "200 OK", "401 Unauthorized", "FAILED"
  String? _buildResponseHint(
      int? statusCode, String? statusMessage, bool failed) {
    if (statusCode == null) return failed ? 'FAILED' : null;
    final msg = statusMessage != null && statusMessage.isNotEmpty
        ? statusMessage
        : _defaultStatusMessage(statusCode);
    return '$statusCode $msg';
  }

  static String _defaultStatusMessage(int code) {
    switch (code) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 204: return 'No Content';
      case 301: return 'Moved Permanently';
      case 302: return 'Found';
      case 304: return 'Not Modified';
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 405: return 'Method Not Allowed';
      case 408: return 'Request Timeout';
      case 409: return 'Conflict';
      case 422: return 'Unprocessable Entity';
      case 429: return 'Too Many Requests';
      case 500: return 'Internal Server Error';
      case 502: return 'Bad Gateway';
      case 503: return 'Service Unavailable';
      default:  return code < 400 ? 'Success' : 'Error';
    }
  }

  String _render(Object? data, LogColor color, List<DetectedToken> tokens) {
    final f = ConsoleJsonFormatter(
      theme,
      collapseDepth: collapseDepth,
      maxArrayItems: maxArrayItems,
      collapseKeys: collapseKeys,
      collapseListItems: collapseListItems,
      collapsePredicate: collapsePredicate,
    );
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
  _Box(this._logger, {int? gap}) : _gap = gap ?? _logger.lineGap;

  final ConsoleLoggerPro _logger;
  final int _gap;
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
    for (var i = 0; i < _gap; i++) {
      buffer.writeln('\u2800' * (i + 1));
    }
    _logger._printer(buffer.toString().trimRight());
  }
}
