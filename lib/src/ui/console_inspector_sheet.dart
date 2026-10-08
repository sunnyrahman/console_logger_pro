// ignore_for_file: prefer_const_declarations

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_call_record.dart';
import '../console_json_formatter.dart';
import '../log_theme.dart';
import 'json_tree_viewer.dart';

/// Full-featured in-app network inspector bottom sheet / modal.
class ConsoleInspectorSheet extends StatefulWidget {
  const ConsoleInspectorSheet({
    super.key,
    required this.records,
    this.onClear,
  });

  final List<ApiCallRecord> records;
  final VoidCallback? onClear;

  /// Shows the inspector as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<ApiCallRecord> records,
    VoidCallback? onClear,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConsoleInspectorSheet(
        records: records,
        onClear: onClear,
      ),
    );
  }

  /// Shows a direct standalone JSON tree viewer dialog.
  static Future<void> showJson(
    BuildContext context, {
    required Object? data,
    String title = 'JSON Viewer',
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D1117),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        child: SizedBox(
          width: 800,
          height: 600,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF161B22),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.data_object,
                        color: Color(0xFF58A6FF), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: JsonTreeViewer(data: data),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<ConsoleInspectorSheet> createState() => _ConsoleInspectorSheetState();
}

class _ConsoleInspectorSheetState extends State<ConsoleInspectorSheet> {
  ApiCallRecord? _selectedRecord;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final darkBg = const Color(0xFF0D1117);
    final borderCol = const Color(0xFF30363D);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: darkBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // App Bar
              _buildHeader(),
              const Divider(color: Color(0xFF30363D), height: 1),

              // Content: List of calls or Detailed view
              Expanded(
                child: _selectedRecord == null
                    ? _buildListView(scrollController)
                    : _buildDetailView(_selectedRecord!),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (_selectedRecord != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color(0xFF58A6FF), size: 20),
              onPressed: () => setState(() => _selectedRecord = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.terminal, color: Color(0xFF58A6FF), size: 22),
          const SizedBox(width: 8),
          const Text(
            'Console Logger Pro',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.records.length}',
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (widget.onClear != null && _selectedRecord == null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white54, size: 20),
              tooltip: 'Clear History',
              onPressed: () {
                widget.onClear?.call();
                setState(() {});
              },
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(ScrollController scrollController) {
    final filtered = widget.records.reversed.where((r) {
      if (_filter.isEmpty) return true;
      return r.url.toLowerCase().contains(_filter) ||
          r.method.toLowerCase().contains(_filter) ||
          (r.statusCode?.toString().contains(_filter) ?? false);
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 34,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) =>
                  setState(() => _filter = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Filter requests by URL, method or status...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon:
                    const Icon(Icons.search, size: 16, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF161B22),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
              ),
            ),
          ),
        ),

        // Requests list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No network requests captured yet.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF21262D), height: 1),
                  itemBuilder: (ctx, idx) {
                    final r = filtered[idx];
                    return _buildRecordRow(r);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecordRow(ApiCallRecord r) {
    final isError = r.isFailed;
    final statusColor =
        isError ? const Color(0xFFF85149) : const Color(0xFF3FB950);

    return InkWell(
      onTap: () => setState(() => _selectedRecord = r),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            // Method badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Text(
                r.method.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Status code
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                r.statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 10),
            // URL
            Expanded(
              child: Text(
                r.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Latency
            if (r.duration != null)
              Text(
                '${r.duration!.inMilliseconds}ms',
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView(ApiCallRecord r) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Endpoint & URL details banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.method.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF58A6FF),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: r.isFailed
                            ? const Color(0xFFF85149).withValues(alpha: 0.2)
                            : const Color(0xFF3FB950).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.statusLabel,
                        style: TextStyle(
                          color: r.isFailed
                              ? const Color(0xFFF85149)
                              : const Color(0xFF3FB950),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (r.duration != null)
                      Text(
                        '${r.duration!.inMilliseconds} ms',
                        style: const TextStyle(
                            color: Color(0xFF8B949E), fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  r.url,
                  style: const TextStyle(
                    color: Color(0xFF79C0FF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          const TabBar(
            isScrollable: true,
            labelColor: Color(0xFF58A6FF),
            unselectedLabelColor: Color(0xFF8B949E),
            indicatorColor: Color(0xFF58A6FF),
            tabs: [
              Tab(text: 'Response Body'),
              Tab(text: 'Request Body'),
              Tab(text: 'Headers'),
              Tab(text: 'Tokens'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                // 1. Response Body with Collapsible Tree
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: r.responseBody != null
                      ? JsonTreeViewer(data: r.responseBody)
                      : const Center(
                          child: Text('No response body.',
                              style: TextStyle(color: Colors.white38))),
                ),

                // 2. Request Body with Collapsible Tree
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: r.requestBody != null
                      ? JsonTreeViewer(data: r.requestBody)
                      : const Center(
                          child: Text('No request body.',
                              style: TextStyle(color: Colors.white38))),
                ),

                // 3. Headers
                _buildHeadersTab(r),

                // 4. Tokens
                _buildTokensTab(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersTab(ApiCallRecord r) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (r.requestHeaders != null && r.requestHeaders!.isNotEmpty) ...[
          const Text(
            'Request Headers',
            style: TextStyle(
              color: Color(0xFF58A6FF),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildHeadersTable(r.requestHeaders!),
          const SizedBox(height: 20),
        ],
        if (r.responseHeaders != null && r.responseHeaders!.isNotEmpty) ...[
          const Text(
            'Response Headers',
            style: TextStyle(
              color: Color(0xFF7EE787),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildHeadersTable(r.responseHeaders!),
        ],
      ],
    );
  }

  Widget _buildHeadersTable(Map<String, dynamic> headers) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: headers.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: SelectableText(
                    '${e.key}:',
                    style: const TextStyle(
                      color: Color(0xFF7EE787),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    '${e.value}',
                    style: const TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTokensTab(ApiCallRecord r) {
    final tokens = <DetectedToken>[];
    // Detect tokens from headers and bodies
    final formatter = ConsoleJsonFormatter(const LogTheme());
    if (r.responseBody != null) formatter.format(r.responseBody);
    tokens.addAll(formatter.tokens);
    if (r.requestHeaders != null) formatter.format(r.requestHeaders);
    for (final t in formatter.tokens) {
      if (!tokens.any((x) => x.value == t.value)) tokens.add(t);
    }

    if (tokens.isEmpty) {
      return const Center(
        child: Text(
          'No security tokens or JWTs detected in this call.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tokens.length,
      itemBuilder: (ctx, i) {
        final t = tokens[i];
        return Card(
          color: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, size: 16, color: Color(0xFFE3B341)),
                    const SizedBox(width: 6),
                    Text(
                      t.label.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFE3B341),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          size: 16, color: Color(0xFF58A6FF)),
                      tooltip: 'Copy Token',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: t.value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Token copied to clipboard!'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF238636),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  t.value,
                  style: const TextStyle(
                    color: Color(0xFFA5D6FF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
