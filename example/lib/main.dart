import 'package:console_logger_pro/console_logger_pro.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  // The only line you need. Works for http, Dio and dart:io.
  ConsoleLoggerPro.install();
  runApp(const MaterialApp(home: Demo()));
}

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () =>
              http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/1')),
          child: const Text('Call API (see console)'),
        ),
      ),
    );
  }
}
