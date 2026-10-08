import 'dart:convert';

import 'log_color.dart';
import 'log_theme.dart';

/// A token found while formatting (JWT, access_token, ...).
class DetectedToken {
  const DetectedToken(this.label, this.value);

  /// JSON key (or header name) the token was found under.
  final String label;

  /// The raw token, without a `Bearer ` prefix.
  final String value;
}

/// Turns decoded JSON into an indented, colorized string.
///
/// Keys use [LogTheme.key], values use the color passed to [format], tokens
/// use [LogTheme.token] and URLs use [LogTheme.link].
class ConsoleJsonFormatter {
  ConsoleJsonFormatter(
    this.theme, {
    this.indent = 2,
    this.collapseDepth,
    this.maxArrayItems,
    this.collapseKeys = const <String>[],
    this.collapseListItems = false,
    this.collapsePredicate,
  });

  final LogTheme theme;
  final int indent;

  /// If non-null, objects and arrays at nesting depth >= [collapseDepth]
  /// are printed in collapsed format: `{...}` or `[...]`.
  final int? collapseDepth;

  /// Maximum items to print per array. Items beyond this count are collapsed
  /// into comments like `// ... (N more items)`.
  final int? maxArrayItems;

  /// JSON keys whose values should be printed in collapsed format `{...}` or `[...]`.
  final List<String> collapseKeys;

  /// When `true`, objects inside arrays are collapsed into `{...}` like in Postman.
  final bool collapseListItems;

  /// Custom predicate to decide whether a value should be collapsed.
  final bool Function(String? key, int level, Object? value)? collapsePredicate;

  /// Tokens found by the last call to [format].
  final List<DetectedToken> tokens = <DetectedToken>[];

  late LogColor _color;

  static final RegExp _linkRegex =
      RegExp(r'''https?://[^\s"'\\<>]*[^\s"'\\<>.,;:!?)\]]''');
  static final RegExp _jwtRegex =
      RegExp(r'^(Bearer\s+)?eyJ[\w-]+\.[\w-]+\.[\w-]*$');
  static final RegExp _bearerRegex =
      RegExp(r'^Bearer\s+', caseSensitive: false);
  static const List<String> _tokenKeyHints = <String>[
    'token',
    'jwt',
    'authorization',
    'apikey',
    'secret',
    'bearer',
    'sessionid',
  ];

  /// Formats [data] (Map / List / primitive / object with `toJson()`) into a
  /// multi-line string. Values are painted with [color]
  /// (defaults to [LogTheme.response]).
  String format(Object? data, {LogColor? color}) {
    tokens.clear();
    _color = color ?? theme.response;
    if (data is String) return _plain(data);
    final buffer = StringBuffer();
    _write(buffer, data, 0, null);
    return buffer.toString();
  }

  String _p(String text) => theme.paint(_color, text);

  String _pad(int level) => ' ' * (level * indent);

  bool _shouldCollapse(String? key, int level, Object? v, {bool insideList = false}) {
    if (collapsePredicate != null && collapsePredicate!(key, level, v)) {
      return true;
    }
    if (collapseDepth != null && level >= collapseDepth!) {
      return true;
    }
    if (key != null && collapseKeys.contains(key)) {
      return true;
    }
    if (insideList && collapseListItems && (v is Map || v is Iterable)) {
      return true;
    }
    return false;
  }

  void _collectTokens(Object? v, String? key) {
    if (v is Map) {
      for (final entry in v.entries) {
        _collectTokens(entry.value, entry.key.toString());
      }
    } else if (v is Iterable) {
      for (final item in v) {
        _collectTokens(item, key);
      }
    } else if (v is String) {
      if (_isToken(v, key)) {
        tokens.add(DetectedToken(
          key ?? 'token',
          v.replaceFirst(_bearerRegex, ''),
        ));
      }
    }
  }

  void _write(StringBuffer b, Object? v, int level, String? key, {bool insideList = false}) {
    final shouldCollapse = _shouldCollapse(key, level, v, insideList: insideList);

    if (v is Map) {
      if (v.isEmpty) {
        b.write(_p('{}'));
        return;
      }
      if (shouldCollapse) {
        _collectTokens(v, key);
        b.write(_p('{...}'));
        return;
      }
      b.writeln(_p('{'));
      final entries = v.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final k = entries[i].key.toString();
        b.write(_pad(level + 1));
        b.write(theme.paint(theme.key, jsonEncode(k)));
        b.write(_p(': '));
        _write(b, entries[i].value, level + 1, k, insideList: false);
        if (i < entries.length - 1) b.write(_p(','));
        b.writeln();
      }
      b.write(_pad(level));
      b.write(_p('}'));
    } else if (v is Iterable) {
      final list = v.toList();
      if (list.isEmpty) {
        b.write(_p('[]'));
        return;
      }
      if (shouldCollapse) {
        _collectTokens(v, key);
        b.write(_p('[...]'));
        return;
      }
      b.writeln(_p('['));
      final limit = maxArrayItems ?? list.length;
      final displayCount = list.length < limit ? list.length : limit;
      for (var i = 0; i < displayCount; i++) {
        b.write(_pad(level + 1));
        _write(b, list[i], level + 1, key, insideList: true);
        if (i < displayCount - 1 || displayCount < list.length) b.write(_p(','));
        b.writeln();
      }
      if (displayCount < list.length) {
        final remaining = list.length - displayCount;
        b.write(_pad(level + 1));
        b.writeln(theme.paint(theme.border, '// ... ($remaining more items)'));
        for (var i = displayCount; i < list.length; i++) {
          _collectTokens(list[i], key);
        }
      }
      b.write(_pad(level));
      b.write(_p(']'));
    } else if (v is String) {
      b.write(_string(v, key));
    } else if (v == null || v is num || v is bool) {
      b.write(_p('$v'));
    } else {
      // Models: use toJson() when available, otherwise toString().
      Object? json;
      try {
        json = (v as dynamic).toJson();
      } catch (_) {}
      if (json is Map || json is Iterable) {
        _write(b, json, level, key, insideList: insideList);
      } else {
        b.write(_string(v.toString(), key));
      }
    }
  }

  bool _isToken(String value, String? key) {
    if (value.length < 8) return false;
    final raw = value.replaceFirst(_bearerRegex, '');
    if (raw.contains(RegExp(r'\s'))) return false;
    if (_jwtRegex.hasMatch(value)) return true;
    if (key == null) return false;
    final k = key.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
    return _tokenKeyHints.any(k.contains);
  }

  String _plain(String text) {
    final trimmed = text.trim();
    if (_isToken(trimmed, null)) {
      tokens
          .add(DetectedToken('token', trimmed.replaceFirst(_bearerRegex, '')));
      return theme.paint(theme.token, trimmed, bold: true);
    }
    return text.split('\n').map(_withLinks).join('\n');
  }

  String _string(String value, String? key) {
    final encoded = jsonEncode(value);
    if (_isToken(value, key)) {
      tokens.add(DetectedToken(
        key ?? 'token',
        value.replaceFirst(_bearerRegex, ''),
      ));
      return theme.paint(theme.token, encoded, bold: true);
    }
    final inner = encoded.substring(1, encoded.length - 1);
    return '${_p('"')}${_withLinks(inner)}${_p('"')}';
  }

  /// Paints [text] with the value color, underlining any URLs.
  String _withLinks(String text) {
    final matches = _linkRegex.allMatches(text).toList();
    if (matches.isEmpty) return _p(text);
    final out = StringBuffer();
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) out.write(_p(text.substring(cursor, m.start)));
      out.write(theme.paint(theme.link, m.group(0)!, underline: true));
      cursor = m.end;
    }
    if (cursor < text.length) out.write(_p(text.substring(cursor)));
    return out.toString();
  }
}
