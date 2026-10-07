import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'body_decoder.dart';
import 'console_logger_pro.dart';

// ---------------------------------------------------------------------------
// Install / uninstall
// ---------------------------------------------------------------------------

_LoggingHttpOverrides? _installed;

void installHttpCapture({
  required ConsoleLoggerPro logger,
  bool Function(Uri uri)? filter,
  required bool logBinary,
  required int maxBodyBytes,
}) {
  uninstallHttpCapture(); // safe to call install() twice
  final overrides = _LoggingHttpOverrides(
    HttpOverrides.current, // keep whatever the app already configured
    _Config(logger, filter, logBinary, maxBodyBytes),
  );
  _installed = overrides;
  HttpOverrides.global = overrides;
}

void uninstallHttpCapture() {
  final installed = _installed;
  if (installed == null) return;
  if (identical(HttpOverrides.current, installed)) {
    HttpOverrides.global = installed.previous;
  }
  _installed = null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _Config {
  _Config(this.logger, this.filter, this.logBinary, this.maxBodyBytes);

  final ConsoleLoggerPro logger;
  final bool Function(Uri uri)? filter;
  final bool logBinary;
  final int maxBodyBytes;

  bool shouldLog(Uri uri) {
    try {
      return filter?.call(uri) ?? true;
    } catch (_) {
      return true;
    }
  }
}

/// Logging must never break the app's networking.
void _safe(void Function() action) {
  try {
    action();
  } catch (_) {}
}

Map<String, dynamic> _headersToMap(HttpHeaders headers) {
  final map = <String, dynamic>{};
  headers.forEach((name, values) {
    map[name] = values.length == 1 ? values.first : values.join(', ');
  });
  return map;
}

class _RequestInfo {
  _RequestInfo(this.method, this.uri, this.headers, this.body)
      : stopwatch = Stopwatch()..start();

  final String method;
  final Uri uri;
  final Map<String, dynamic> headers;
  final DecodedBody? body;
  final Stopwatch stopwatch;
}

// ---------------------------------------------------------------------------
// HttpOverrides
// ---------------------------------------------------------------------------

class _LoggingHttpOverrides extends HttpOverrides {
  _LoggingHttpOverrides(this.previous, this.config);

  final HttpOverrides? previous;
  final _Config config;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = previous != null
        ? previous!.createHttpClient(context)
        : super.createHttpClient(context);
    return _LoggingHttpClient(inner, config);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return previous != null
        ? previous!.findProxyFromEnvironment(url, environment)
        : super.findProxyFromEnvironment(url, environment);
  }
}

// ---------------------------------------------------------------------------
// HttpClient wrapper
// ---------------------------------------------------------------------------

class _LoggingHttpClient implements HttpClient {
  _LoggingHttpClient(this._inner, this._config);

  final HttpClient _inner;
  final _Config _config;

  Future<HttpClientRequest> _wrap(Future<HttpClientRequest> future) async {
    final request = await future;
    if (!_config.shouldLog(request.uri)) return request;
    return _LoggingRequest(request, _config);
  }

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _inner.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      _wrap(_inner.open(method, host, port, path));
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _wrap(_inner.openUrl(method, url));

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _wrap(_inner.get(host, port, path));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _wrap(_inner.getUrl(url));

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _wrap(_inner.post(host, port, path));
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _wrap(_inner.postUrl(url));

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _wrap(_inner.put(host, port, path));
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _wrap(_inner.putUrl(url));

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _wrap(_inner.delete(host, port, path));
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _wrap(_inner.deleteUrl(url));

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _wrap(_inner.patch(host, port, path));
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _wrap(_inner.patchUrl(url));

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _wrap(_inner.head(host, port, path));
  @override
  Future<HttpClientRequest> headUrl(Uri url) => _wrap(_inner.headUrl(url));

  /// Members added in newer Dart SDKs (connectionFactory, keyLog) are
  /// forwarded dynamically so the wrapper keeps working across SDK versions.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (invocation.isSetter &&
        (name.contains('connectionFactory') || name.contains('keyLog'))) {
      final target = _inner as dynamic;
      if (name.contains('connectionFactory')) {
        target.connectionFactory = invocation.positionalArguments.first;
      } else {
        target.keyLog = invocation.positionalArguments.first;
      }
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}

// ---------------------------------------------------------------------------
// Request wrapper (captures the request body)
// ---------------------------------------------------------------------------

class _LoggingRequest implements HttpClientRequest {
  _LoggingRequest(this._inner, this._config);

  final HttpClientRequest _inner;
  final _Config _config;
  final List<int> _body = <int>[];
  bool _bodyTruncated = false;

  void _capture(List<int> data) {
    _safe(() {
      final room = _config.maxBodyBytes - _body.length;
      if (room <= 0) {
        _bodyTruncated = true;
        return;
      }
      if (data.length > room) {
        _body.addAll(data.sublist(0, room));
        _bodyTruncated = true;
      } else {
        _body.addAll(data);
      }
    });
  }

  void _captureText(String text) {
    _safe(() => _capture(_inner.encoding.encode(text)));
  }

  _RequestInfo _snapshot() {
    Map<String, dynamic> headers = <String, dynamic>{};
    DecodedBody? body;
    _safe(() {
      headers = _headersToMap(_inner.headers);
      final type = _inner.headers.contentType;
      body = decodeBody(
        _body,
        mimeType: type?.mimeType,
        boundary: type?.parameters['boundary'],
        truncated: _bodyTruncated,
      );
    });
    return _RequestInfo(_inner.method, _inner.uri, headers, body);
  }

  @override
  Future<HttpClientResponse> close() async {
    // WebSocket handshakes (Upgrade requests) are never wrapped, so realtime
    // connections (web_socket_channel, Pusher, ...) behave exactly as before.
    var isUpgrade = false;
    _safe(() => isUpgrade = _inner.headers[HttpHeaders.upgradeHeader] != null);
    if (isUpgrade) return _inner.close();

    final info = _snapshot();
    try {
      final response = await _inner.close();
      var binary = false;
      _safe(
          () => binary = isBinaryMime(response.headers.contentType?.mimeType));
      if (binary && !_config.logBinary) return response;
      return _LoggingResponse(response, _config, info);
    } catch (error) {
      _safe(() => _config.logger.logApi(
            method: info.method,
            url: info.uri.toString(),
            requestHeaders: info.headers,
            requestBody: info.body?.value,
            requestBodyType: info.body?.type,
            error: error,
            duration: info.stopwatch.elapsed,
          ));
      rethrow;
    }
  }

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  void add(List<int> data) {
    _capture(data);
    _inner.add(data);
  }

  @override
  Future addStream(Stream<List<int>> stream) => _inner.addStream(
        stream.map((chunk) {
          _capture(chunk);
          return chunk;
        }),
      );

  @override
  void write(Object? object) {
    _captureText('$object');
    _inner.write(object);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    _captureText(objects.join(separator));
    _inner.writeAll(objects, separator);
  }

  @override
  void writeln([Object? object = '']) {
    _captureText('$object\n');
    _inner.writeln(object);
  }

  @override
  void writeCharCode(int charCode) {
    _captureText(String.fromCharCode(charCode));
    _inner.writeCharCode(charCode);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future flush() => _inner.flush();

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  List<Cookie> get cookies => _inner.cookies;
  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;
  @override
  HttpHeaders get headers => _inner.headers;
  @override
  String get method => _inner.method;
  @override
  Uri get uri => _inner.uri;
}

// ---------------------------------------------------------------------------
// Response wrapper (tees the body, logs when the stream finishes)
// ---------------------------------------------------------------------------

class _LoggingResponse extends Stream<List<int>> implements HttpClientResponse {
  _LoggingResponse(this._inner, this._config, this._info);

  final HttpClientResponse _inner;
  final _Config _config;
  final _RequestInfo _info;
  final List<int> _buffer = <int>[];
  bool _truncated = false;
  bool _logged = false;

  void _capture(List<int> chunk) {
    _safe(() {
      final room = _config.maxBodyBytes - _buffer.length;
      if (room <= 0) {
        _truncated = true;
        return;
      }
      if (chunk.length > room) {
        _buffer.addAll(chunk.sublist(0, room));
        _truncated = true;
      } else {
        _buffer.addAll(chunk);
      }
    });
  }

  void _logSuccess() {
    if (_logged) return;
    _logged = true;
    _safe(() {
      var bytes = _buffer;
      if (_inner.compressionState ==
          HttpClientResponseCompressionState.compressed) {
        try {
          bytes = gzip.decode(bytes);
        } catch (_) {}
      }
      final body = decodeBody(
        bytes,
        mimeType: _inner.headers.contentType?.mimeType,
        truncated: _truncated,
      );
      _config.logger.logApi(
        method: _info.method,
        url: _info.uri.toString(),
        statusCode: _inner.statusCode,
        statusMessage: _inner.reasonPhrase,
        requestHeaders: _info.headers,
        requestBody: _info.body?.value,
        requestBodyType: _info.body?.type,
        responseHeaders: _headersToMap(_inner.headers),
        responseBody: body?.value,
        duration: _info.stopwatch.elapsed,
      );
    });
  }

  void _logFailure(Object error) {
    if (_logged) return;
    _logged = true;
    _safe(() => _config.logger.logApi(
          method: _info.method,
          url: _info.uri.toString(),
          statusCode: _inner.statusCode,
          requestHeaders: _info.headers,
          requestBody: _info.body?.value,
          requestBodyType: _info.body?.type,
          error: error,
          duration: _info.stopwatch.elapsed,
        ));
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Consumers such as Dio call `listen()` and then swap handlers through
    // `subscription.onData(...)`. Returning the raw inner subscription would
    // let them overwrite our capture callback, so the body would never be
    // logged. The wrapper keeps capture in place whatever handlers are set.
    return _CaptureSubscription(
      this,
      onData: onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get statusCode => _inner.statusCode;
  @override
  String get reasonPhrase => _inner.reasonPhrase;
  @override
  int get contentLength => _inner.contentLength;
  @override
  HttpClientResponseCompressionState get compressionState =>
      _inner.compressionState;
  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  bool get isRedirect => _inner.isRedirect;
  @override
  List<RedirectInfo> get redirects => _inner.redirects;
  @override
  HttpHeaders get headers => _inner.headers;
  @override
  List<Cookie> get cookies => _inner.cookies;
  @override
  X509Certificate? get certificate => _inner.certificate;
  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  Future<HttpClientResponse> redirect(
          [String? method, Uri? url, bool? followLoops]) =>
      _inner.redirect(method, url, followLoops);

  @override
  Future<Socket> detachSocket() => _inner.detachSocket();
}

// ---------------------------------------------------------------------------
// Subscription wrapper (capture can't be bypassed by handler swaps)
// ---------------------------------------------------------------------------

class _CaptureSubscription implements StreamSubscription<List<int>> {
  _CaptureSubscription(
    this._response, {
    void Function(List<int> event)? onData,
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  })  : _onData = onData,
        _onError = onError,
        _onDone = onDone {
    _sub = _response._inner.listen(
      _handleData,
      onError: _handleError,
      onDone: _handleDone,
      cancelOnError: cancelOnError,
    );
  }

  final _LoggingResponse _response;
  late final StreamSubscription<List<int>> _sub;
  void Function(List<int> event)? _onData;
  Function? _onError;
  void Function()? _onDone;

  void _handleData(List<int> chunk) {
    _response._capture(chunk);
    _onData?.call(chunk);
  }

  void _handleError(Object error, StackTrace stack) {
    _response._logFailure(error);
    final handler = _onError;
    if (handler == null) {
      Zone.current.handleUncaughtError(error, stack);
    } else if (handler is void Function(Object, StackTrace)) {
      handler(error, stack);
    } else if (handler is void Function(Object)) {
      handler(error);
    } else {
      Function.apply(handler, [error, stack]);
    }
  }

  void _handleDone() {
    _response._logSuccess();
    _onDone?.call();
  }

  @override
  void onData(void Function(List<int> data)? handleData) =>
      _onData = handleData;

  @override
  void onError(Function? handleError) => _onError = handleError;

  @override
  void onDone(void Function()? handleDone) => _onDone = handleDone;

  @override
  void pause([Future<void>? resumeSignal]) => _sub.pause(resumeSignal);

  @override
  void resume() => _sub.resume();

  @override
  bool get isPaused => _sub.isPaused;

  @override
  Future<void> cancel() {
    // Some clients cancel once they have read Content-Length bytes, so onDone
    // never fires. Log whatever was received.
    _response._logSuccess();
    return _sub.cancel();
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    _onDone = () => completer.complete(futureValue as E);
    _onError = (Object error, StackTrace stack) {
      _sub.cancel();
      completer.completeError(error, stack);
    };
    return completer.future;
  }
}
