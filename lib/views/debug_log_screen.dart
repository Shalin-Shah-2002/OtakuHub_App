import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger_service.dart';

/// Debug screen for viewing logs and error information
class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  LogLevel? _filterLevel;
  String _filterTag = '';
  final _searchController = TextEditingController();
  bool _autoScroll = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    logger.logNavigation('previous', 'DebugLogScreen');

    // Auto-scroll when new logs arrive
    logger.logStream.listen((_) {
      if (_autoScroll && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filteredLogs {
    return logger.logHistory.where((entry) {
      if (_filterLevel != null && entry.level != _filterLevel) return false;
      if (_filterTag.isNotEmpty &&
          !entry.tag.toLowerCase().contains(_filterTag.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          // Error count badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.error_outline),
                onPressed: () => setState(() => _filterLevel = LogLevel.error),
                tooltip: 'Show errors only',
              ),
              if (logger.errorCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${logger.errorCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom
                  : Icons.vertical_align_center,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            tooltip: _autoScroll ? 'Disable auto-scroll' : 'Enable auto-scroll',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  logger.clearHistory();
                  setState(() {});
                  break;
                case 'export':
                  _exportLogs();
                  break;
                case 'summary':
                  _showErrorSummary();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear logs')),
              const PopupMenuItem(value: 'export', child: Text('Export logs')),
              const PopupMenuItem(
                value: 'summary',
                child: Text('Error summary'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                // Level filter
                DropdownButton<LogLevel?>(
                  value: _filterLevel,
                  hint: const Text('Level'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...LogLevel.values.map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Row(
                          children: [
                            _getLevelIcon(level),
                            const SizedBox(width: 4),
                            Text(level.name),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _filterLevel = value),
                ),
                const SizedBox(width: 8),
                // Tag filter
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Filter by tag...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.filter_list, size: 20),
                      suffixIcon: _filterTag.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _filterTag = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => setState(() => _filterTag = value),
                  ),
                ),
              ],
            ),
          ),
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${_filteredLogs.length} logs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Errors: ${logger.errorCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: logger.errorCount > 0 ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ),
          // Log list
          Expanded(
            child: StreamBuilder(
              stream: logger.logStream,
              builder: (context, snapshot) {
                final logs = _filteredLogs;

                if (logs.isEmpty) {
                  return const Center(child: Text('No logs to display'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final entry = logs[index];
                    return _LogEntryTile(entry: entry);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return const Icon(Icons.text_snippet, size: 16, color: Colors.grey);
      case LogLevel.debug:
        return const Icon(Icons.bug_report, size: 16, color: Colors.cyan);
      case LogLevel.info:
        return const Icon(Icons.info, size: 16, color: Colors.green);
      case LogLevel.warning:
        return const Icon(Icons.warning, size: 16, color: Colors.orange);
      case LogLevel.error:
        return const Icon(Icons.error, size: 16, color: Colors.red);
      case LogLevel.fatal:
        return const Icon(Icons.dangerous, size: 16, color: Colors.purple);
    }
  }

  void _exportLogs() {
    final json = logger.exportLogsAsJson();
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard')));
  }

  void _showErrorSummary() {
    final summary = logger.getErrorSummary();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Errors: ${summary['totalErrors']}'),
              const Divider(),
              const Text(
                'Errors by Tag:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(summary['errorsByTag'] as Map<String, int>).entries.map(
                (e) => Text('  ${e.key}: ${e.value}'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isError =
        entry.level == LogLevel.error || entry.level == LogLevel.fatal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: isError ? Colors.red.withOpacity(0.1) : null,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildLevelBadge(),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.tag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(entry.timestamp),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.message,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.error != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${entry.error}',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge() {
    Color color;
    String emoji;

    switch (entry.level) {
      case LogLevel.verbose:
        color = Colors.grey;
        emoji = '📝';
        break;
      case LogLevel.debug:
        color = Colors.cyan;
        emoji = '🔍';
        break;
      case LogLevel.info:
        color = Colors.green;
        emoji = '💡';
        break;
      case LogLevel.warning:
        color = Colors.orange;
        emoji = '⚠️';
        break;
      case LogLevel.error:
        color = Colors.red;
        emoji = '❌';
        break;
      case LogLevel.fatal:
        color = Colors.purple;
        emoji = '💀';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 12)),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  _buildLevelBadge(),
                  const SizedBox(width: 8),
                  Text(
                    entry.tag,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: entry.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log copied')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow('Time', entry.timestamp.toString()),
              _buildDetailRow('Level', entry.level.name.toUpperCase()),
              _buildDetailRow('Message', entry.message),
              if (entry.error != null)
                _buildDetailRow('Error', entry.error.toString()),
              if (entry.stackTrace != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    entry.stackTrace.toString(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              if (entry.extras != null && entry.extras!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Extras:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...entry.extras!.entries.map(
                  (e) => _buildDetailRow(e.key, e.value.toString()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
