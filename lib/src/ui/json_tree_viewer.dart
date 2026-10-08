import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive, Postman-style collapsible JSON Tree Viewer widget for Flutter.
///
/// Features:
/// - Clickable bracket-to-bracket folding (`{...}` and `[...]`).
/// - Expand All / Collapse All buttons.
/// - One-click Copy JSON to clipboard.
/// - In-tree search and highlight.
/// - Beautiful dark IDE theme with syntax highlighting and indent guides.
class JsonTreeViewer extends StatefulWidget {
  const JsonTreeViewer({
    super.key,
    required this.data,
    this.initiallyExpanded = true,
    this.showLineNumbers = false,
  });

  /// The JSON data (Map, List, String, or primitive).
  final Object? data;

  /// Whether all nodes are initially expanded.
  final bool initiallyExpanded;

  /// Whether to display line numbers in the margin.
  final bool showLineNumbers;

  @override
  State<JsonTreeViewer> createState() => _JsonTreeViewerState();
}

class _JsonTreeViewerState extends State<JsonTreeViewer> {
  late Object? _normalizedData;
  final Set<String> _collapsedPaths = <String>{};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _normalizedData = _normalize(widget.data);
    if (!widget.initiallyExpanded) {
      _collapseAll();
    }
  }

  @override
  void didUpdateWidget(covariant JsonTreeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      setState(() {
        _normalizedData = _normalize(widget.data);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static Object? _normalize(Object? input) {
    if (input is String) {
      final trimmed = input.trimLeft();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return jsonDecode(input);
        } catch (_) {}
      }
    }
    return input;
  }

  void _collapseAll() {
    setState(() {
      _collectAllPaths(_normalizedData, 'root', _collapsedPaths);
    });
  }

  void _expandAll() {
    setState(() {
      _collapsedPaths.clear();
    });
  }

  void _collectAllPaths(Object? v, String path, Set<String> out) {
    if (v is Map) {
      out.add(path);
      var idx = 0;
      for (final entry in v.entries) {
        _collectAllPaths(entry.value, '$path.k$idx', out);
        idx++;
      }
    } else if (v is Iterable) {
      out.add(path);
      var idx = 0;
      for (final item in v) {
        _collectAllPaths(item, '$path.i$idx', out);
        idx++;
      }
    }
  }

  void _toggle(String path) {
    setState(() {
      if (_collapsedPaths.contains(path)) {
        _collapsedPaths.remove(path);
      } else {
        _collapsedPaths.add(path);
      }
    });
  }

  void _copyToClipboard() {
    final text = const JsonEncoder.withIndent('  ').convert(_normalizedData);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JSON copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF238636),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF0D1117);
    const borderCol = Color(0xFF30363D);

    return Container(
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                // Expand All button
                _ToolbarButton(
                  icon: Icons.unfold_more,
                  label: 'Expand All',
                  onTap: _expandAll,
                ),
                const SizedBox(width: 6),
                // Collapse All button
                _ToolbarButton(
                  icon: Icons.unfold_less,
                  label: 'Collapse All',
                  onTap: _collapseAll,
                ),
                const SizedBox(width: 8),
                // Search box
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim().toLowerCase());
                      },
                      decoration: InputDecoration(
                        hintText: 'Filter JSON...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                        prefixIcon: const Icon(Icons.search,
                            size: 14, color: Colors.white54),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 26, minHeight: 26),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: borderCol),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: borderCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF58A6FF)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Copy button
                _ToolbarButton(
                  icon: Icons.copy,
                  label: 'Copy',
                  onTap: _copyToClipboard,
                ),
              ],
            ),
          ),

          // Collapsible JSON Tree body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildNode(_normalizedData, 'root', isRoot: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(
    Object? v,
    String path, {
    String? fieldKey,
    bool isRoot = false,
    bool isLast = true,
  }) {
    if (v is Map) {
      return _buildMapNode(v, path, fieldKey: fieldKey, isLast: isLast);
    } else if (v is Iterable) {
      return _buildListNode(v.toList(), path, fieldKey: fieldKey, isLast: isLast);
    } else {
      return _buildPrimitiveNode(v, fieldKey: fieldKey, isLast: isLast);
    }
  }

  Widget _buildMapNode(
    Map map,
    String path, {
    String? fieldKey,
    required bool isLast,
  }) {
    final isCollapsed = _collapsedPaths.contains(path);
    final keyLabel = fieldKey != null ? '"$fieldKey": ' : '';

    if (map.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fieldKey != null) _KeyText(keyLabel, _searchQuery),
          const Text('{}', style: TextStyle(color: Color(0xFFE6EDF3), fontFamily: 'monospace', fontSize: 13)),
          if (!isLast) const Text(',', style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13)),
        ],
      );
    }

    if (isCollapsed) {
      return InkWell(
        onTap: () => _toggle(path),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_right, size: 16, color: Color(0xFF7EE787)),
              if (fieldKey != null) _KeyText(keyLabel, _searchQuery),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Text(
                  '{... ${map.length} keys}',
                  style: const TextStyle(
                    color: Color(0xFFE3B341),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isLast)
                const Text(',', style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final entries = map.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Opening brace with collapse toggle
        InkWell(
          onTap: () => _toggle(path),
          borderRadius: BorderRadius.circular(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF7EE787)),
              if (fieldKey != null) _KeyText(keyLabel, _searchQuery),
              const Text('{', style: TextStyle(color: Color(0xFFE3B341), fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // Children inside indent guide
        Container(
          margin: const EdgeInsets.only(left: 7),
          padding: const EdgeInsets.only(left: 12),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFF21262D), width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                _buildNode(
                  entries[i].value,
                  '$path.k$i',
                  fieldKey: entries[i].key.toString(),
                  isLast: i == entries.length - 1,
                ),
            ],
          ),
        ),
        // Closing brace
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16),
            const Text('}', style: TextStyle(color: Color(0xFFE3B341), fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
            if (!isLast) const Text(',', style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildListNode(
    List list,
    String path, {
    String? fieldKey,
    required bool isLast,
  }) {
    final isCollapsed = _collapsedPaths.contains(path);
    final keyLabel = fieldKey != null ? '"$fieldKey": ' : '';

    if (list.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fieldKey != null) _KeyText(keyLabel, _searchQuery),
          const Text('[]', style: TextStyle(color: Color(0xFFE6EDF3), fontFamily: 'monospace', fontSize: 13)),
          if (!isLast) const Text(',', style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13)),
        ],
      );
    }

    if (isCollapsed) {
      return InkWell(
        onTap: () => _toggle(path),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_right, size: 16, color: Color(0xFF58A6FF)),
              if (fieldKey != null) _KeyText(keyLabel, _searchQuery),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Text(
                  '[... ${list.length} items]',
                  style: const TextStyle(
                    color: Color(0xFF58A6FF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isLast)
                const Text(',', style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Opening bracket with toggle
        InkWell(
          onTap: () => _toggle(path),
          borderRadius: BorderRadius.circular(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF58A6FF)),
              if (fieldKey != null) _KeyText(keyLabel, _searchQuery),
              const Text('[', style: TextStyle(color: Color(0xFF58A6FF), fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // Elements inside indent guide
        Container(
          margin: const EdgeInsets.only(left: 7),
          padding: const EdgeInsets.only(left: 12),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFF21262D), width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < list.length; i++)
                _buildNode(
                  list[i],
                  '$path.i$i',
                  isLast: i == list.length - 1,
                ),
            ],
          ),
        ),
        // Closing bracket
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16),
            const Text(']', style: TextStyle(color: Color(0xFF58A6FF), fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
            if (!isLast) const Text(',', style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimitiveNode(
    Object? v, {
    String? fieldKey,
    required bool isLast,
  }) {
    final keyLabel = fieldKey != null ? '"$fieldKey": ' : '';
    Color valColor = const Color(0xFF79C0FF);
    String valStr = '$v';

    if (v is String) {
      valColor = const Color(0xFFA5D6FF);
      valStr = jsonEncode(v);
    } else if (v is num) {
      valColor = const Color(0xFFD2A8FF);
    } else if (v is bool) {
      valColor = v ? const Color(0xFF7EE787) : const Color(0xFFFFA198);
    } else if (v == null) {
      valColor = const Color(0xFF8B949E);
    }

    final isMatch = _searchQuery.isNotEmpty &&
        (valStr.toLowerCase().contains(_searchQuery) ||
            (fieldKey != null && fieldKey.toLowerCase().contains(_searchQuery)));

    return Container(
      color: isMatch ? const Color(0x33F2CC60) : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16),
          if (fieldKey != null) _KeyText(keyLabel, _searchQuery),
          Text(
            valStr,
            style: TextStyle(
              color: valColor,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          if (!isLast)
            const Text(',', style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13)),
        ],
      ),
    );
  }
}

class _KeyText extends StatelessWidget {
  const _KeyText(this.text, this.query);

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF7EE787),
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF58A6FF)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC9D1D9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
