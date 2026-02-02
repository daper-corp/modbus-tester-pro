import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../widgets/industrial_button.dart';

/// Enhanced log viewing and export screen with advanced features
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  LogType? _filterType;
  bool _autoScroll = true;
  bool _showSearch = false;
  String _searchQuery = '';
  Set<String> _bookmarkedIds = {};
  bool _showOnlyBookmarked = false;
  bool _showOnlyErrors = false;
  
  // Time range filter
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Main toolbar
            _buildToolbar(provider),
            
            // Search bar (conditional)
            if (_showSearch) _buildSearchBar(),
            
            // Filter chips
            _buildFilterChips(provider),
            
            // Advanced filters indicator
            if (_hasActiveFilters()) _buildActiveFiltersBar(),
            
            // Log list
            Expanded(
              child: StreamBuilder<List<LogEntry>>(
                stream: provider.logService.logStream,
                initialData: provider.logService.logs,
                builder: (context, snapshot) {
                  final logs = _filterLogs(snapshot.data ?? []);
                  return logs.isEmpty
                      ? _buildEmptyState()
                      : _buildLogList(logs, provider);
                },
              ),
            ),
            
            // Bottom stats bar
            _buildStatsBar(provider),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.article, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          const Text(
            'COMMUNICATION LOG',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          
          // Search toggle
          ActionButton(
            icon: Icons.search,
            tooltip: 'Search',
            isActive: _showSearch,
            size: 36,
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          const SizedBox(width: 4),
          
          // Bookmark filter toggle
          ActionButton(
            icon: _showOnlyBookmarked ? Icons.bookmark : Icons.bookmark_border,
            tooltip: _showOnlyBookmarked ? 'Show All' : 'Show Bookmarked',
            isActive: _showOnlyBookmarked,
            size: 36,
            onPressed: _bookmarkedIds.isNotEmpty
                ? () => setState(() => _showOnlyBookmarked = !_showOnlyBookmarked)
                : null,
          ),
          const SizedBox(width: 4),
          
          // Error filter toggle
          ActionButton(
            icon: Icons.error_outline,
            tooltip: _showOnlyErrors ? 'Show All' : 'Show Errors Only',
            isActive: _showOnlyErrors,
            size: 36,
            onPressed: () => setState(() => _showOnlyErrors = !_showOnlyErrors),
          ),
          const SizedBox(width: 4),
          
          // Auto-scroll toggle
          ActionButton(
            icon: _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            isActive: _autoScroll,
            size: 36,
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          const SizedBox(width: 4),
          
          // More options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surfaceElevated,
            onSelected: (value) => _handleMenuAction(value, provider),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_txt',
                child: Row(
                  children: [
                    Icon(Icons.description, size: 18),
                    SizedBox(width: 8),
                    Text('Export Text'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_json',
                child: Row(
                  children: [
                    Icon(Icons.code, size: 18),
                    SizedBox(width: 8),
                    Text('Export JSON'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'copy_all',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 18),
                    SizedBox(width: 8),
                    Text('Copy All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_bookmarks',
                child: Row(
                  children: [
                    Icon(Icons.bookmark_remove, size: 18),
                    SizedBox(width: 8),
                    Text('Clear Bookmarks'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Clear All Logs', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceLight,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search logs... (address, data, message)',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildFilterChips(ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', null),
            const SizedBox(width: 8),
            _buildFilterChip('TX', LogType.request, AppColors.fcRead),
            const SizedBox(width: 8),
            _buildFilterChip('RX', LogType.response, AppColors.success),
            const SizedBox(width: 8),
            _buildFilterChip('Error', LogType.error, AppColors.error),
            const SizedBox(width: 8),
            _buildFilterChip('Connection', LogType.connection, AppColors.accentSecondary),
            const SizedBox(width: 8),
            _buildFilterChip('Info', LogType.info, AppColors.accent),
            const SizedBox(width: 8),
            _buildFilterChip('Warning', LogType.warning, AppColors.warning),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, LogType? type, [Color? color]) {
    final isSelected = _filterType == type;
    final chipColor = color ?? AppColors.textSecondary;
    
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipColor : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
           _showOnlyBookmarked ||
           _showOnlyErrors ||
           _startTime != null ||
           _endTime != null;
  }

  Widget _buildActiveFiltersBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'Active filters: ${_getActiveFilterText()}',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearAllFilters,
            child: const Text(
              'Clear',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActiveFilterText() {
    List<String> filters = [];
    if (_searchQuery.isNotEmpty) filters.add('search');
    if (_showOnlyBookmarked) filters.add('bookmarked');
    if (_showOnlyErrors) filters.add('errors');
    return filters.join(', ');
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _showOnlyBookmarked = false;
      _showOnlyErrors = false;
      _startTime = null;
      _endTime = null;
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasActiveFilters() ? Icons.search_off : Icons.article_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters()
                ? 'No logs match your filters'
                : 'No communication logs yet',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          if (_hasActiveFilters())
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildLogList(List<LogEntry> logs, ModbusProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: logs.length,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemBuilder: (context, index) {
        final log = logs[logs.length - 1 - index]; // Newest first
        final isBookmarked = _bookmarkedIds.contains(log.id);
        
        return _buildLogItem(log, isBookmarked);
      },
    );
  }

  Widget _buildLogItem(LogEntry log, bool isBookmarked) {
    final typeColor = _getLogTypeColor(log.type);
    
    return GestureDetector(
      onLongPress: () => _showLogDetailDialog(log),
      onDoubleTap: () => _toggleBookmark(log.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: log.isError
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isBookmarked ? AppColors.warning : AppColors.border,
            width: isBookmarked ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            
            // Timestamp
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.formattedTimestamp,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    log.direction,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log.message != null)
                    Text(
                      log.message!,
                      style: TextStyle(
                        color: log.isError ? AppColors.error : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (log.hexDump.isNotEmpty)
                    Text(
                      log.hexDump,
                      style: const TextStyle(
                        color: AppColors.dataValue,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // Bookmark indicator
            if (isBookmarked)
              const Icon(Icons.bookmark, size: 16, color: AppColors.warning),
            
            // Response time (if available)
            if (log.response?.responseTimeMs != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _getResponseTimeColor(log.response!.responseTimeMs).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${log.response!.responseTimeMs}ms',
                  style: TextStyle(
                    color: _getResponseTimeColor(log.response!.responseTimeMs),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLogDetailDialog(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getLogTypeColor(log.type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.direction,
                style: TextStyle(
                  color: _getLogTypeColor(log.type),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Log Detail', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Timestamp', log.timestamp.toString()),
              if (log.message != null) _buildDetailRow('Message', log.message!),
              if (log.hexDump.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'HEX DUMP',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    log.hexDump,
                    style: const TextStyle(
                      color: AppColors.dataValue,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              if (log.request != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'REQUEST DETAILS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildDetailRow('Function', log.request!.functionCode.name),
                _buildDetailRow('Slave ID', log.request!.slaveId.toString()),
                _buildDetailRow('Address', log.request!.startAddress.toString()),
                _buildDetailRow('Quantity', log.request!.quantity.toString()),
              ],
              if (log.response != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'RESPONSE DETAILS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildDetailRow('Success', log.response!.success.toString()),
                _buildDetailRow('Response Time', '${log.response!.responseTimeMs}ms'),
                if (log.response!.exceptionCode != null)
                  _buildDetailRow('Exception', log.response!.exceptionName),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _formatLogForCopy(log)));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLogForCopy(LogEntry log) {
    final buffer = StringBuffer();
    buffer.writeln('=== Modbus Log Entry ===');
    buffer.writeln('Timestamp: ${log.timestamp}');
    buffer.writeln('Type: ${log.type.name}');
    buffer.writeln('Direction: ${log.direction}');
    if (log.message != null) buffer.writeln('Message: ${log.message}');
    if (log.hexDump.isNotEmpty) buffer.writeln('Hex Dump: ${log.hexDump}');
    if (log.request != null) {
      buffer.writeln('--- Request ---');
      buffer.writeln('Function: ${log.request!.functionCode.name}');
      buffer.writeln('Slave ID: ${log.request!.slaveId}');
      buffer.writeln('Address: ${log.request!.startAddress}');
      buffer.writeln('Quantity: ${log.request!.quantity}');
    }
    if (log.response != null) {
      buffer.writeln('--- Response ---');
      buffer.writeln('Success: ${log.response!.success}');
      buffer.writeln('Response Time: ${log.response!.responseTimeMs}ms');
      if (log.response!.exceptionCode != null) {
        buffer.writeln('Exception: ${log.response!.exceptionName}');
      }
    }
    return buffer.toString();
  }

  void _toggleBookmark(String logId) {
    setState(() {
      if (_bookmarkedIds.contains(logId)) {
        _bookmarkedIds.remove(logId);
      } else {
        _bookmarkedIds.add(logId);
      }
    });
  }

  Widget _buildStatsBar(ModbusProvider provider) {
    final logs = provider.logService.logs;
    final requestCount = logs.where((l) => l.type == LogType.request).length;
    final responseCount = logs.where((l) => l.type == LogType.response && !l.isError).length;
    final errorCount = logs.where((l) => l.isError).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', logs.length.toString(), AppColors.textSecondary),
          _buildStatItem('TX', requestCount.toString(), AppColors.fcRead),
          _buildStatItem('RX', responseCount.toString(), AppColors.success),
          _buildStatItem('ERR', errorCount.toString(), AppColors.error),
          _buildStatItem('★', _bookmarkedIds.length.toString(), AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  List<LogEntry> _filterLogs(List<LogEntry> logs) {
    var filtered = logs;
    
    // Type filter
    if (_filterType != null) {
      filtered = filtered.where((log) => log.type == _filterType).toList();
    }
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((log) {
        final message = log.message?.toLowerCase() ?? '';
        final hexDump = log.hexDump.toLowerCase();
        return message.contains(_searchQuery) || hexDump.contains(_searchQuery);
      }).toList();
    }
    
    // Bookmark filter
    if (_showOnlyBookmarked) {
      filtered = filtered.where((log) => _bookmarkedIds.contains(log.id)).toList();
    }
    
    // Error filter
    if (_showOnlyErrors) {
      filtered = filtered.where((log) => log.isError).toList();
    }
    
    return filtered;
  }

  void _handleMenuAction(String action, ModbusProvider provider) {
    switch (action) {
      case 'export_csv':
        _exportLogs(provider, 'csv');
        break;
      case 'export_txt':
        _exportLogs(provider, 'txt');
        break;
      case 'export_json':
        _exportLogs(provider, 'json');
        break;
      case 'copy_all':
        _copyAllLogs(provider);
        break;
      case 'clear_bookmarks':
        setState(() => _bookmarkedIds.clear());
        break;
      case 'clear':
        _showClearDialog(provider);
        break;
    }
  }

  void _exportLogs(ModbusProvider provider, String format) {
    String content;
    String filename;
    
    switch (format) {
      case 'csv':
        content = provider.logService.exportToCsv();
        filename = 'modbus_log_${DateTime.now().millisecondsSinceEpoch}.csv';
        break;
      case 'txt':
        content = provider.logService.exportToText();
        filename = 'modbus_log_${DateTime.now().millisecondsSinceEpoch}.txt';
        break;
      case 'json':
        content = provider.logService.exportToJson();
        filename = 'modbus_log_${DateTime.now().millisecondsSinceEpoch}.json';
        break;
      default:
        return;
    }
    
    _showExportPreview(content, filename);
  }

  void _copyAllLogs(ModbusProvider provider) {
    final content = provider.logService.exportToText();
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All logs copied to clipboard')),
    );
  }

  void _showExportPreview(String content, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.file_download, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(filename, style: const TextStyle(fontSize: 14))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${content.length} bytes',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
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

  void _showClearDialog(ModbusProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Clear Logs'),
        content: const Text(
          'Are you sure you want to clear all communication logs? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearLogs();
              setState(() => _bookmarkedIds.clear());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Color _getLogTypeColor(LogType type) {
    switch (type) {
      case LogType.request:
        return AppColors.fcRead;
      case LogType.response:
        return AppColors.success;
      case LogType.error:
        return AppColors.error;
      case LogType.warning:
        return AppColors.warning;
      case LogType.info:
        return AppColors.accent;
      case LogType.connection:
        return AppColors.accentSecondary;
    }
  }

  Color _getResponseTimeColor(int time) {
    if (time < 50) return AppColors.success;
    if (time < 100) return AppColors.ledOn;
    if (time < 200) return AppColors.warning;
    return AppColors.error;
  }
}
