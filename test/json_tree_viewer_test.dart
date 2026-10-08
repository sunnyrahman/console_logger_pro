import 'package:console_logger_pro/console_logger_pro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('JsonTreeViewer interactive collapse and expand test',
      (tester) async {
    final testData = {
      'company': 'Softvence',
      'developer': {
        'name': 'Naymur',
        'role': 'Flutter Dev',
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JsonTreeViewer(data: testData),
        ),
      ),
    );

    expect(find.textContaining('Softvence'), findsOneWidget);
    expect(find.textContaining('Naymur'), findsOneWidget);

    // Tap "Collapse All" button
    await tester.tap(find.text('Collapse All'));
    await tester.pumpAndSettle();

    // Now root object is collapsed into {... 2 keys}
    expect(find.text('{... 2 keys}'), findsOneWidget);

    // Tap "Expand All" button
    await tester.tap(find.text('Expand All'));
    await tester.pumpAndSettle();

    // Now expanded back
    expect(find.textContaining('Naymur'), findsOneWidget);
  });
}
