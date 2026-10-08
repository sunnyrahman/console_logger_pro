import 'log_color.dart';

/// Professional color theme for [ConsoleLoggerPro].
///
/// Every section of the network log has its own dedicated color for
/// instant visual distinction in the console:
///
/// * [endpoint]: Cyan (URL path)
/// * [methodGet]: Bright Blue ([GET])
/// * [methodPost]: Bright Green ([POST])
/// * [methodPut]: Yellow / Amber ([PUT])
/// * [methodDelete]: Bright Red ([DELETE])
/// * [methodPatch]: Pink / Magenta ([PATCH])
/// * [success]: Green (2xx / 3xx responses)
/// * [error]: Red (4xx / 5xx responses & exceptions)
/// * [response]: Gold / Warm Yellow (Response payload)
/// * [body]: Pink / Magenta (Request payload)
/// * [params]: Bright Blue (Query parameters)
/// * [token]: Bright Cyan (Highlighted security tokens)
/// * [userData]: Purple / Magenta (Client user action payloads)
/// * [log]: Crisp White (General log messages)
/// * [border]: Subtle Gray (Box framing lines)
class LogTheme {
  const LogTheme({
    this.endpoint = LogColor.cyan,
    this.methodGet = LogColor.brightBlue,
    this.methodPost = LogColor.brightGreen,
    this.methodPut = LogColor.yellow,
    this.methodDelete = LogColor.brightRed,
    this.methodPatch = LogColor.pink,
    this.success = LogColor.brightGreen,
    this.error = LogColor.brightRed,
    this.response = LogColor.yellow,
    this.body = LogColor.pink,
    this.params = LogColor.brightBlue,
    this.requestHeader = LogColor.brightCyan,
    this.responseHeader = LogColor.gold,
    this.request = LogColor.cyan,
    this.click = LogColor.orange,
    this.debug = LogColor.violet,
    this.info = LogColor.brightBlue,
    this.warning = LogColor.yellow,
    this.log = LogColor.white,
    this.token = LogColor.pink,
    this.userData = LogColor.magenta,
    this.key = LogColor.white,
    this.link = LogColor.brightCyan,
    this.border = LogColor.gray,
    this.useColors = true,
  });

  /// Color of the `https://endpoint` path.
  final LogColor endpoint;

  /// HTTP Method badge colors.
  final LogColor methodGet;
  final LogColor methodPost;
  final LogColor methodPut;
  final LogColor methodDelete;
  final LogColor methodPatch;

  /// Returns the dedicated badge color for a given HTTP [method].
  LogColor methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return methodGet;
      case 'POST':
        return methodPost;
      case 'PUT':
        return methodPut;
      case 'DELETE':
        return methodDelete;
      case 'PATCH':
        return methodPatch;
      default:
        return endpoint;
    }
  }

  /// Successful status line (2xx / 3xx).
  final LogColor success;

  /// Failed status line (4xx / 5xx / network error) and error messages.
  final LogColor error;

  /// Response body content.
  final LogColor response;

  /// Request body content (JSON, form-data, form-urlencoded).
  final LogColor body;

  /// Query parameters.
  final LogColor params;

  /// Request headers section.
  final LogColor requestHeader;

  /// Response headers section.
  final LogColor responseHeader;

  /// Overall request section or payload.
  final LogColor request;

  /// UI Click / Tap / Interaction events.
  final LogColor click;

  /// Debug logs & state inspections.
  final LogColor debug;

  /// Informational messages.
  final LogColor info;

  /// Warning messages.
  final LogColor warning;

  /// General messages from [ConsoleLoggerPro.log].
  final LogColor log;

  /// 🔑 Tokens (JWT, `access_token`, `Authorization`, ...).
  final LogColor token;

  /// User data submitted from the UI / forms.
  final LogColor userData;

  /// JSON keys and header names.
  final LogColor key;

  /// URLs found inside JSON values (underlined).
  final LogColor link;

  /// Box border lines and metadata labels.
  final LogColor border;

  /// Whether ANSI colors are enabled. Defaults to `true`.
  final bool useColors;

  /// Paints [text] with [color] if [useColors] is true.
  String paint(
    LogColor color,
    String text, {
    bool bold = false,
    bool underline = false,
  }) {
    if (!useColors) return text;
    return color.paint(text, bold: bold, underline: underline);
  }
}
