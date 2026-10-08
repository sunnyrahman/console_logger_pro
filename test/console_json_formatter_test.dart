// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:console_logger_pro/console_logger_pro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects tokens and keeps links', () {
    final f = ConsoleJsonFormatter(const LogTheme(useColors: false));
    final out = f.format({
      'access_token': 'abcdefghij123',
      'profile': 'https://example.com/me.png',
    });
    expect(f.tokens.single.value, 'abcdefghij123');
    expect(out, contains('https://example.com/me.png'));
  });

  test('detects JWT by shape', () {
    final f = ConsoleJsonFormatter(const LogTheme(useColors: false));
    f.format({'x': 'eyJhbGciOiJI.eyJzdWIiOiIx.sig123'});
    expect(f.tokens, hasLength(1));
  });

  test('logger prints lines', () {
    final lines = <String>[];
    ConsoleLoggerPro(
      enabled: true,
      theme: const LogTheme(useColors: false),
      printer: lines.add,
    ).logResponse(
      method: 'GET',
      url: 'https://api.test/users',
      statusCode: 200,
      body: '{"ok":true}',
    );
    expect(lines.join('\n'), contains('[GET]  https://api.test/users'));
  });

  test('install() captures plain dart:io requests', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      req.response.headers.contentType = ContentType.json;
      req.response
          .write(jsonEncode({'access_token': 'abcdefghij123', 'ok': true}));
      await req.response.close();
    });
    final lines = <String>[];
    ConsoleLoggerPro.install(
      logger: ConsoleLoggerPro(
        enabled: true,
        theme: const LogTheme(useColors: false),
        printer: lines.add,
      ),
    );
    final client = HttpClient();
    final request =
        await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/users'));
    final response = await request.close();
    await response.drain<void>();
    client.close();
    ConsoleLoggerPro.uninstall();
    await server.close(force: true);

    final out = lines.join('\n');
    expect(out, contains('/users'));
    expect(out, contains('abcdefghij123'));
    expect(out, contains('200'));
  });

  test('install() logs response body when read via cast() (like Dio)',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'task': 'Fix login', 'id': 42}));
      await req.response.close();
    });
    final lines = <String>[];
    ConsoleLoggerPro.install(
      logger: ConsoleLoggerPro(
        enabled: true,
        theme: const LogTheme(useColors: false),
        printer: lines.add,
      ),
    );
    final client = HttpClient();
    final request =
        await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/tasks'));
    final response = await request.close();
    final body = await utf8.decodeStream(response.cast<List<int>>());
    client.close();
    ConsoleLoggerPro.uninstall();
    await server.close(force: true);

    expect(body, contains('Fix login'));
    final out = lines.join('\n');
    expect(out, contains('Response'));
    expect(out, contains('Fix login'));
  });

  test('line order test for consecutive API calls', () {
    final lines = <String>[];
    final logger = ConsoleLoggerPro(
      enabled: true,
      theme: const LogTheme(useColors: false),
      printer: lines.add,
      lineGap: 3,
    );
    // API 1: /user/tasks
    logger.logApi(
      method: 'GET',
      url: 'https://api.test/tasks',
      statusCode: 200,
      statusMessage: 'OK',
      requestHeaders: {'authorization': 'Bearer eyJ_TOKEN_VALUE_1'},
      responseBody: {'message': 'Tasks retrieved successfully.'},
    );

    // API 2: /user/leaves
    logger.logApi(
      method: 'GET',
      url: 'https://api.test/leaves',
      statusCode: 200,
      statusMessage: 'OK',
      requestHeaders: {'authorization': 'Bearer eyJ_TOKEN_VALUE_2'},
      responseBody: {'message': 'Leaves retrieved successfully.'},
    );

    final allLines = lines.expand((b) => b.split('\n')).toList();
    final tokenIdx = allLines
        .indexWhere((l) => l.contains('authorization: eyJ_TOKEN_VALUE_1'));
    final bottomIdx = allLines.indexWhere((l) => l.contains('└'));
    final gapIdx = allLines.indexWhere((l) => l.contains('\u2800'));
    final nextApiIdx = allLines.indexWhere((l) => l.contains('/leaves'));

    expect(tokenIdx, greaterThan(-1));
    expect(bottomIdx, greaterThan(tokenIdx),
        reason: 'Bottom border must come AFTER token');
    expect(gapIdx, greaterThan(bottomIdx),
        reason: 'Gap space must come AFTER bottom border');
    expect(nextApiIdx, greaterThan(gapIdx),
        reason: 'Next API must come AFTER gap space');
  });

  test('logApi outputs [Request Headers] and [Request Body] above [Response]', () {
    final lines = <String>[];
    final logger = ConsoleLoggerPro(
      enabled: true,
      theme: const LogTheme(useColors: false),
      printer: lines.add,
    );

    logger.logApi(
      method: 'POST',
      url: 'https://api.test/login',
      statusCode: 200,
      statusMessage: 'OK',
      requestHeaders: {
        'content-type': 'application/json',
        'authorization': 'Bearer sample_token_123',
      },
      requestBody: {
        'email': 'user@example.com',
        'password': 'secretpassword',
      },
      requestBodyType: 'form-data',
      responseBody: {'success': true, 'token': 'jwt_abc'},
    );

    final text = lines.join('\n');
    expect(text, contains('[Request Headers]'));
    expect(text, contains('content-type'));
    expect(text, contains('[Request Body (form-data)]'));
    expect(text, contains('user@example.com'));
    expect(text, contains('[Response]'));
    expect(text, contains('jwt_abc'));

    // Check order: Request Headers -> Request Body -> Response
    final headersIdx = text.indexOf('[Request Headers]');
    final bodyIdx = text.indexOf('[Request Body (form-data)]');
    final responseIdx = text.indexOf('[Response]');

    expect(headersIdx, lessThan(bodyIdx));
    expect(bodyIdx, lessThan(responseIdx));
  });

  test('failed request logs complete request headers, body and error', () {
    final lines = <String>[];
    final logger = ConsoleLoggerPro(
      enabled: true,
      showRequestHeaders: false, // even when false, failed request MUST show full request
      theme: const LogTheme(useColors: false),
      printer: lines.add,
    );

    logger.logApi(
      method: 'POST',
      url: 'https://api.test/failed-endpoint',
      statusCode: 401,
      statusMessage: 'Unauthorized',
      requestHeaders: {'x-api-key': 'secret-key-999'},
      requestBody: {'param': 'test_payload'},
      error: 'Invalid credentials provided',
    );

    final text = lines.join('\n');
    expect(text, contains('[401 Unauthorized]'));
    expect(text, contains('[Request Headers]'));
    expect(text, contains('secret-key-999'));
    expect(text, contains('[Request Body]'));
    expect(text, contains('test_payload'));
    expect(text, contains('[Error]'));
    expect(text, contains('Invalid credentials provided'));
  });

  test('click and onClick format into structured section', () {
    final lines = <String>[];
    final logger = ConsoleLoggerPro(
      enabled: true,
      theme: const LogTheme(useColors: false),
      printer: lines.add,
    );

    logger.logClick('Login Button Clicked', data: {'screen': 'LoginScreen'});
    final text = lines.join('\n');
    expect(text, contains('[ON CLICK]  Login Button Clicked'));
    expect(text, contains('[Event Data]'));
    expect(text, contains('LoginScreen'));
    expect(text, contains('┌'));
    expect(text, contains('└'));
  });

  test('debug formats into structured section with data', () {
    final lines = <String>[];
    final logger = ConsoleLoggerPro(
      enabled: true,
      theme: const LogTheme(useColors: false),
      printer: lines.add,
    );

    logger.logDebug('State changed', data: {'isLoading': false, 'count': 5});
    final text = lines.join('\n');
    expect(text, contains('[DEBUG]  State changed'));
    expect(text, contains('[Debug Data]'));
    expect(text, contains('isLoading'));
    expect(text, contains('┌'));
    expect(text, contains('└'));
  });

  test('print and error format into clean section with borders and stack trace', () {
    final lines = <String>[];
    final logger = ConsoleLoggerPro(
      enabled: true,
      theme: const LogTheme(useColors: false),
      printer: lines.add,
    );

    logger.logPrint('Custom print message');
    logger.logException(
      'Payment processing failed',
      error: 'NetworkTimeoutException',
      stackTrace: StackTrace.current,
    );

    final text = lines.join('\n');
    expect(text, contains('[PRINT]  Custom print message'));
    expect(text, contains('[ERROR]  Payment processing failed'));
    expect(text, contains('[Error]'));
    expect(text, contains('NetworkTimeoutException'));
  });

  test('collapseDepth collapses nested objects into {...} and arrays into [...]', () {
    final formatter = ConsoleJsonFormatter(
      const LogTheme(useColors: false),
      collapseDepth: 1,
    );

    final data = {
      'level0': {
        'level1': {'name': 'test'},
      },
    };

    final result = formatter.format(data);
    expect(result, contains('"level0": {...}'));
  });

  test('collapseKeys collapses specified keys like data into [...]', () {
    final formatter = ConsoleJsonFormatter(
      const LogTheme(useColors: false),
      collapseKeys: ['data'],
    );

    final data = {
      'success': true,
      'code': 200,
      'data': [
        {'id': 1, 'name': 'Toyota'},
        {'id': 2, 'name': 'Honda'},
      ],
      'pagination': {'total': 2},
    };

    final result = formatter.format(data);
    expect(result, contains('"data": [...]'));
    expect(result, contains('"pagination": {'));
  });

  test('collapseListItems collapses objects inside arrays to {...} matching Postman', () {
    final formatter = ConsoleJsonFormatter(
      const LogTheme(useColors: false),
      collapseListItems: true,
    );

    final data = {
      'data': [
        {'id': 7, 'name': 'Toyota Hiace'},
        {'id': 8, 'name': 'Nissan Caravan'},
      ],
    };

    final result = formatter.format(data);
    expect(result, contains('{...}'));
    expect(result, isNot(contains('"Toyota Hiace"')));
  });

  test('maxArrayItems limits array output with item count summary', () {
    final formatter = ConsoleJsonFormatter(
      const LogTheme(useColors: false),
      maxArrayItems: 2,
    );

    final data = {
      'items': [1, 2, 3, 4, 5],
    };

    final result = formatter.format(data);
    expect(result, contains('1,'));
    expect(result, contains('2,'));
    expect(result, contains('// ... (3 more items)'));
  });

  test('tokens inside collapsed JSON are still captured and detected', () {
    final formatter = ConsoleJsonFormatter(
      const LogTheme(useColors: false),
      collapseKeys: ['auth'],
    );

    final data = {
      'auth': {
        'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.t-IDcSemACt8x4iTMCda8Yhe3iZaWbvV5XKSTbuAn0M',
      },
    };

    final result = formatter.format(data);
    expect(result, contains('"auth": {...}'));
    expect(formatter.tokens, hasLength(1));
    expect(formatter.tokens.first.value, contains('eyJhbGci'));
  });

  test('ConsoleLoggerPro stores history of network requests in memory', () {
    final lines = <String>[];
    final logger = ConsoleLoggerPro(
      enabled: true,
      theme: const LogTheme(useColors: false),
      printer: lines.add,
      maxHistoryLength: 10,
    );

    logger.clearRecords();
    expect(logger.records, isEmpty);

    logger.logApi(
      method: 'GET',
      url: 'https://api.test/items',
      statusCode: 200,
      responseBody: {'count': 5},
    );

    expect(logger.records, hasLength(1));
    expect(logger.records.first.method, 'GET');
    expect(logger.records.first.url, 'https://api.test/items');
    expect(logger.records.first.statusCode, 200);
    expect(logger.records.first.statusLabel, contains('200'));
  });
}
