import 'package:flutter/foundation.dart';

import 'console_logger_pro.dart';

/// Web / unsupported platforms: automatic capture is not available.
void installHttpCapture({
  required ConsoleLoggerPro logger,
  bool Function(Uri uri)? filter,
  required bool logBinary,
  required int maxBodyBytes,
}) {
  debugPrint(
    'console_logger_pro: automatic capture is not supported on this platform '
    '(Flutter web). Use logger.logRequest / logResponse manually.',
  );
}

void uninstallHttpCapture() {}
