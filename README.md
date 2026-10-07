# console_logger_pro

A Flutter package for logging HTTP and Dio requests in a clean, readable console format.

[![pub package](https://img.shields.io/pub/v/console_logger_pro.svg)](https://pub.dev/packages/console_logger_pro)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

`console_logger_pro` is a zero-boilerplate network logger for Flutter that formats messy API logs into clean, color-coded console blocks.

With just a single call in `main()`, it captures traffic across `http`, `Dio`, and native `HttpClient`—preventing logs from overlapping during concurrent requests, color-coding status codes, and copying auth tokens directly to your clipboard for effortless testing.

## Getting started

Add the package to your project:

```bash
flutter pub add console_logger_pro
```

Or add it to your `pubspec.yaml`:

```yaml
dependencies:
  console_logger_pro: ^1.0.0
```

## Usage

Call `ConsoleLoggerPro.install()` in your `main()` function before `runApp()`:

```dart
import 'package:flutter/material.dart';
import 'package:console_logger_pro/console_logger_pro.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ConsoleLoggerPro.install();

  runApp(const MyApp());
}
```

Once installed, any network call made by your app will be formatted in the console automatically.

## Console Output

Here is how network requests appear in the debug console with color-coded HTTP methods, status badges, and automatic token detection:

<p align="center">
  <img src="https://raw.githubusercontent.com/sunnyrahman/console_logger_pro/main/screenshots/preview.png" alt="Console Output Preview" width="100%"/>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/sunnyrahman/console_logger_pro/main/screenshots/preview2.png" alt="Console Output Detailed Preview" width="100%"/>
</p>

## Features

- **Global capture**: Automatically logs requests made via `http`, `Dio`, and `dart:io HttpClient`.
- **Atomic output**: Each request and response is framed in a single block, avoiding jumbled logs from concurrent network calls.
- **Token extraction**: Detects Bearer tokens, JWTs, and API keys, displaying them separately and optionally copying them to your clipboard.
- **Configurable spacing**: Adds blank lines between requests so your console remains readable during heavy API usage.
- **Debug-only by default**: Disabled automatically in production builds (`kDebugMode`).

## Customization

You can pass configuration options to `ConsoleLoggerPro.install()`:

```dart
ConsoleLoggerPro.install(
  logger: ConsoleLoggerPro(
    lineGap: 2,                 // Empty lines between requests (default: 3)
    autoCopyToken: true,        // Copy detected tokens to clipboard (default: true)
    showRequestHeaders: false,  // Print request headers (default: false)
    showResponseHeaders: false, // Print response headers (default: false)
    lineWidth: 80,              // Frame width in characters (default: 80)
    maxLines: 300,              // Payload line limit before truncation (default: 300)
  ),
  filter: (uri) {
    // Return false to skip logging specific endpoints (e.g. analytics or health checks)
    return !uri.path.contains('/analytics');
  },
  logBinary: false, // Set to true if you want binary payloads logged
);
```

### Changing Colors

To adjust the console color scheme, use `LogTheme`:

```dart
ConsoleLoggerPro.install(
  logger: ConsoleLoggerPro(
    theme: const LogTheme(
      endpoint: LogColor.cyan,
      success: LogColor.green,
      error: LogColor.red,
      response: LogColor.yellow,
      border: LogColor.gray,
    ),
  ),
);
```

## Manual Logging

You can also use the logger for non-HTTP messages or general app events:

```dart
// General log
ConsoleLoggerPro.log('Order created', data: {'orderId': 452});

// User action tracking
ConsoleLoggerPro.userData('User opened checkout screen');
```

## How It Works

This package works by setting a custom `HttpOverrides` during `ConsoleLoggerPro.install()`. This intercepts network connections at Dart's core I/O layer, capturing headers, payloads, and response statuses before forwarding them normally.

## Issues and Feedback

If you find a bug or have a suggestion, please open an issue on [GitHub](https://github.com/sunnyrahman/console_logger_pro/issues).

## License

MIT License. See [LICENSE](LICENSE) for details.
