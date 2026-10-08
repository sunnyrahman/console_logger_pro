import 'log_color.dart';

/// Represents a captured API network call stored in memory for in-app inspection.
class ApiCallRecord {
  ApiCallRecord({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    this.statusCode,
    this.statusMessage,
    this.requestHeaders,
    this.requestBody,
    this.requestBodyType,
    this.responseHeaders,
    this.responseBody,
    this.error,
    this.stackTrace,
    this.duration,
  });

  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, dynamic>? requestHeaders;
  final Object? requestBody;
  final String? requestBodyType;
  final Map<String, dynamic>? responseHeaders;
  final Object? responseBody;
  final Object? error;
  final StackTrace? stackTrace;
  final Duration? duration;

  /// Whether this request failed with 4xx, 5xx or a network error.
  bool get isFailed => error != null || (statusCode != null && statusCode! >= 400);

  /// Status badge label (e.g. `200 OK`, `401 Unauthorized`, `FAILED`).
  String get statusLabel {
    if (statusCode != null) {
      final msg = statusMessage != null && statusMessage!.isNotEmpty
          ? ' $statusMessage'
          : '';
      return '$statusCode$msg';
    }
    return isFailed ? 'FAILED' : 'PENDING';
  }

  /// HTTP Method badge background/text color.
  LogColor get methodColor {
    switch (method.toUpperCase()) {
      case 'GET':
        return LogColor.green;
      case 'POST':
        return LogColor.brightCyan;
      case 'PUT':
        return LogColor.gold;
      case 'DELETE':
        return LogColor.brightRed;
      case 'PATCH':
        return LogColor.pink;
      default:
        return LogColor.white;
    }
  }
}
