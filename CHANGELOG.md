## 1.0.0

- Initial stable release of `console_logger_pro`.
- Zero-setup automatic network capture for `http`, `Dio`, and `dart:io HttpClient` via `ConsoleLoggerPro.install()`.
- Atomic box rendering to prevent log message interleaving in IDE debug consoles.
- Color badges for all HTTP methods (`[GET]`, `[POST]`, `[PUT]`, `[DELETE]`, `[PATCH]`).
- Automatic security token detection (JWT, Bearer, API Keys) and clipboard copying.
- Configurable line gap (`lineGap`) between consecutive API calls.
- Clickable underlined URLs inside JSON responses.
- Manual logging utilities (`ConsoleLoggerPro.log`, `ConsoleLoggerPro.userData`).
