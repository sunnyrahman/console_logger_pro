import 'dart:convert';

/// A request / response body turned into something readable.
class DecodedBody {
  const DecodedBody(this.value, [this.type]);

  /// Decoded JSON, a `Map` of form fields, or plain text.
  final Object? value;

  /// Short label such as `json`, `form-data`, `form-urlencoded`.
  final String? type;
}

/// Whether bodies of this MIME type should not be printed as text.
bool isBinaryMime(String? mime) {
  if (mime == null) return false;
  final m = mime.toLowerCase();
  return m.startsWith('image/') ||
      m.startsWith('video/') ||
      m.startsWith('audio/') ||
      m.startsWith('font/') ||
      m == 'application/octet-stream' ||
      m == 'application/pdf' ||
      m == 'application/zip';
}

/// `1536` -> `1.5 KB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Decodes raw body [bytes] based on its content type.
///
/// * `multipart/form-data` -> `{field: value, file: '📎 name.jpg (12 KB)'}`
/// * `application/x-www-form-urlencoded` -> `{field: value}`
/// * JSON -> decoded `Map` / `List`
/// * anything else -> text
DecodedBody? decodeBody(
  List<int> bytes, {
  String? mimeType,
  String? boundary,
  bool truncated = false,
}) {
  if (bytes.isEmpty) return null;
  final mime = mimeType?.toLowerCase();

  if (isBinaryMime(mime)) {
    return DecodedBody('<${formatBytes(bytes.length)}, $mime>', 'binary');
  }

  if (mime == 'multipart/form-data') {
    final fields = parseMultipart(bytes, boundary);
    if (fields != null) {
      return DecodedBody(
          fields, truncated ? 'form-data, truncated' : 'form-data');
    }
  }

  final text = utf8.decode(bytes, allowMalformed: true);

  if (mime == 'application/x-www-form-urlencoded') {
    try {
      return DecodedBody(Uri.splitQueryString(text), 'form-urlencoded');
    } catch (_) {}
  }

  final start = text.trimLeft();
  final looksJson = (mime != null && mime.contains('json')) ||
      start.startsWith('{') ||
      start.startsWith('[');
  if (looksJson) {
    try {
      return DecodedBody(jsonDecode(text), 'json');
    } catch (_) {}
  }

  return DecodedBody(
    truncated ? '$text … (truncated)' : text,
    truncated ? 'text, truncated' : 'text',
  );
}

final RegExp _nameRegex = RegExp(r'(?:^|[;\s])name="([^"]*)"');
final RegExp _fileRegex = RegExp(r'filename="([^"]*)"');
final RegExp _typeRegex =
    RegExp(r'content-type:\s*([^\r\n;]+)', caseSensitive: false);

/// Parses a `multipart/form-data` body into `{field: value}`. File parts are
/// summarized (name, size, type) instead of dumping their bytes.
/// Returns `null` when the body can't be parsed.
Map<String, Object?>? parseMultipart(List<int> bytes, String? boundary) {
  // latin1 maps every byte to one char, so lengths stay byte-accurate and
  // binary file content can't break decoding.
  final text = latin1.decode(bytes);
  var b = boundary;
  if (b == null || b.isEmpty) {
    if (!text.startsWith('--')) return null;
    final end = text.indexOf('\r\n');
    if (end < 0) return null;
    b = text.substring(2, end);
  }

  final result = <String, Object?>{};
  for (var part in text.split('--$b')) {
    if (part.startsWith('--')) break; // closing delimiter
    if (part.startsWith('\r\n')) part = part.substring(2);
    final split = part.indexOf('\r\n\r\n');
    if (split < 0) continue;
    final head = part.substring(0, split);
    var content = part.substring(split + 4);
    if (content.endsWith('\r\n')) {
      content = content.substring(0, content.length - 2);
    }

    final name = _nameRegex.firstMatch(head)?.group(1) ?? 'field';
    final filename = _fileRegex.firstMatch(head)?.group(1);
    final Object? value;
    if (filename != null) {
      final type = _typeRegex.firstMatch(head)?.group(1)?.trim();
      final info = [formatBytes(content.length), if (type != null) type];
      value = '📎 $filename (${info.join(', ')})';
    } else {
      value = utf8.decode(latin1.encode(content), allowMalformed: true);
    }

    final previous = result[name];
    if (!result.containsKey(name)) {
      result[name] = value;
    } else if (previous is List) {
      previous.add(value);
    } else {
      result[name] = <Object?>[previous, value];
    }
  }
  return result.isEmpty ? null : result;
}
