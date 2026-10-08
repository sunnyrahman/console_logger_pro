
## 1.2.0

- Response section now shows human-readable status code next to label: `[Response]  (200 OK)`, `[Response]  (401 Unauthorized)`.
- Added 2 blank visual spacer lines before `[Response]` and `[Error]` sections for cleaner log readability.
- Built-in status message map for common HTTP codes (200, 201, 400, 401, 403, 404, 422, 429, 500, 502, 503, etc.).
- **Postman-Style JSON Collapsing in Console**: Added `collapseDepth`, `collapseKeys`, `collapseListItems`, `maxArrayItems`, and `collapsePredicate` parameters to `ConsoleLoggerPro` and `ConsoleJsonFormatter` to format large objects and arrays into `{...}` and `[...]` matching Postman's folding feature.
- **In-App Network Inspector (`ConsoleLoggerPro.showInspector`)**: Full-featured in-app dark modal bottom sheet that tracks recent requests in memory with clickable bracket-to-bracket JSON folding, HTTP method badges, status labels, headers viewer, and 1-tap token copying.
- **Interactive `JsonTreeViewer` Widget**: Standalone embeddable Flutter widget with real clickable bracket folding (`{...}` and `[...]`), Expand All, Collapse All, Copy JSON, and search filtering.
- **Direct JSON Modal (`ConsoleLoggerPro.showJsonViewer`)**: Open any JSON data in an interactive collapsible dialog with zero setup.
- Token detection now preserves and captures security tokens even from collapsed JSON payloads.

## 1.1.0

- Added dedicated `[Request Headers]` section (default enabled) styled in Bright Cyan above `[Response]`.
- Added dedicated `[Request Body]` section styled in Pink.
- Added comprehensive error logging on request failure with full request headers, payload, response error, and stack trace frames.
- Added UI interaction logging: `ConsoleLoggerPro.click` and `ConsoleLoggerPro.onClick` in vibrant orange box styling.
- Added debugging and app utility logging: `ConsoleLoggerPro.debug`, `ConsoleLoggerPro.print`, `ConsoleLoggerPro.info`, `ConsoleLoggerPro.warning`, and `ConsoleLoggerPro.error`.
- Added new theme color tokens: `requestHeader`, `responseHeader`, `request`, `click`, `debug`, `info`, and `warning`.
- Added ANSI color constants: `orange`, `violet`, and `teal`.

## 1.0.0

- Initial stable release of `console_logger_pro`.
- Zero-setup automatic network capture for `http`, `Dio`, and `dart:io HttpClient` via `ConsoleLoggerPro.install()`.
- Atomic box rendering to prevent log message interleaving in IDE debug consoles.
- Color badges for all HTTP methods (`[GET]`, `[POST]`, `[PUT]`, `[DELETE]`, `[PATCH]`).
- Automatic security token detection (JWT, Bearer, API Keys) and clipboard copying.
- Configurable line gap (`lineGap`) between consecutive API calls.
- Clickable underlined URLs inside JSON responses.
- Manual logging utilities (`ConsoleLoggerPro.log`, `ConsoleLoggerPro.userData`).
