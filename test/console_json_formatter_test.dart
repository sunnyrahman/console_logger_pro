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
}
