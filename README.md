# console_logger_pro

A Flutter package for logging HTTP and Dio requests in a clean, readable console format.

[![pub package](https://img.shields.io/pub/v/console_logger_pro.svg)](https://pub.dev/packages/console_logger_pro)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

`console_logger_pro` is a zero-boilerplate network logger for Flutter that formats messy API logs into clean, color-coded console blocks.

With just a single call in `main()`, it captures traffic across `http`, `Dio`, and native `HttpClient` - preventing logs from overlapping during concurrent requests, color-coding status codes, and copying auth tokens directly to your clipboard for effortless testing.

## Getting started

Add the package to your project:

```bash
flutter pub add console_logger_pro
```

Or add it to your `pubspec.yaml`:

```yaml
dependencies:
  console_logger_pro: ^1.1.0
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

## Key Features

- **Zero-Boilerplate Setup**: Just one line `ConsoleLoggerPro.install()` in `main()` - captures all `http`, `Dio`, and native `dart:io` traffic with zero interceptors required.
- **Full Request Visibility**: Dedicated `[Request Headers]` (Bright Cyan) and `[Request Body]` (Pink) rendered right above `[Response]` (Gold) so you know exactly what payload and auth went out.
- **Bulletproof Error & Failure Logs**: When an API call fails (4xx, 5xx, or network timeouts), it prints the complete request headers, payload, response error, and stack trace frames.
- **Auto-Copy Security Tokens**: Instantly detects JWTs, Bearer tokens, and API keys, highlights them, and automatically copies them to your clipboard for zero-click Postman pasting.
- **UI Click & Event Logging**: Track button presses and taps with `ConsoleLoggerPro.click('...')` or `onClick(...)` styled in vibrant orange boxes with event payloads.
- **Complete In-App Debug Suite**: Built-in structured logging for `debug()`, `print()`, `info()`, `warning()`, and `error()`—all formatted with clean box borders and dedicated colors.
- **Atomic, Concurrent-Safe Output**: Each network call and debug message prints in an isolated, synchronized box with customizable spacing (`lineGap`) to prevent messy overlapping console lines.
- **100% Production-Safe**: Automatically disabled outside `kDebugMode` with zero overhead in production.

## Customization

You can pass configuration options to `ConsoleLoggerPro.install()`:

```dart
ConsoleLoggerPro.install(
  logger: ConsoleLoggerPro(
    lineGap: 2,                 // Empty lines between requests (default: 3)
    autoCopyToken: true,        // Copy detected tokens to clipboard (default: true)
    showRequestHeaders: true,   // Print request headers above response (default: true)
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
      requestHeader: LogColor.brightCyan,
      responseHeader: LogColor.gold,
      success: LogColor.green,
      error: LogColor.red,
      response: LogColor.yellow,
      body: LogColor.pink,
      click: LogColor.orange,
      debug: LogColor.violet,
      border: LogColor.gray,
    ),
  ),
);
```

## Manual & UI Event Logging

You can use the logger anywhere in your app (buttons, clicks, debugging, and printing) with clean, structured boxes and dedicated colors:

```dart
// 1. UI Click / Tap Interaction
ElevatedButton(
  onPressed: () {
    ConsoleLoggerPro.click('Login button clicked', data: {
      'email': emailController.text,
    });
  },
  child: const Text('Login'),
);

// 2. State & Variable Debugging
ConsoleLoggerPro.debug('User profile state updated', data: user.toJson());

// 3. Form / User Data Submission
ConsoleLoggerPro.userData('Registration Form Submitted', formData);

// 4. Clean Print Replacement
ConsoleLoggerPro.print('Screen navigated: /dashboard');

// 5. Info, Warning & Error Handling
ConsoleLoggerPro.info('Network cache refreshed');
ConsoleLoggerPro.warning('Session expiring in 2 minutes');
ConsoleLoggerPro.error('Payment checkout failed', error: e, stackTrace: stack);
```

## How It Works

This package works by setting a custom `HttpOverrides` during `ConsoleLoggerPro.install()`. This intercepts network connections at Dart's core I/O layer, capturing headers, payloads, and response statuses before forwarding them normally.

## Issues and Feedback

If you find a bug or have a suggestion, please open an issue on [GitHub](https://github.com/sunnyrahman/console_logger_pro/issues).

## License

MIT License. See [LICENSE](LICENSE) for details.
