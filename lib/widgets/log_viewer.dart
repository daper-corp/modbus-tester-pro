import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/modbus_models.dart';

/// Log entry viewer widget
class LogViewer extends StatelessWidget {
  final List<LogEntry> logs;
  final ScrollController? scrollController;
  final bool autoScroll;

  const LogViewer({
    super.key,
    required this.logs,
    this.scrollController,
    this.autoScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                color: AppColors.textMuted,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'No logs yet',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Communication logs will appear here',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return LogEntryTile(entry: log);
      },
    );
  }
}

/// Individual log entry tile
class LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const LogEntryTile({
    super.key,
    required this.entry,
  });

  Color get _typeColor {
    switch (entry.type) {
      case LogType.request:
        return AppColors.fcRead;
      case LogType.response:
        return entry.isError ? AppColors.error : AppColors.success;
      case LogType.info:
        return AppColors.accent;
      case LogType.warning:
        return AppColors.warning;
      case LogType.error:
        return AppColors.error;
      case LogType.connection:
        return AppColors.accentSecondary;
    }
  }

  IconData get _typeIcon {
    switch (entry.type) {
      case LogType.request:
        return Icons.upload_outlined;
      case LogType.response:
        return entry.isError ? Icons.error_outline : Icons.download_outlined;
      case LogType.info:
        return Icons.info_outline;
      case LogType.warning:
        return Icons.warning_amber;
      case LogType.error:
        return Icons.error_outline;
      case LogType.connection:
        return Icons.cable;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: entry.isError 
            ? AppColors.error.withValues(alpha: 0.1) 
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: entry.isError ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showDetails(context),
          onLongPress: () => _copyToClipboard(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Direction indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_typeIcon, color: _typeColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            entry.direction,
                            style: TextStyle(
                              color: _typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timestamp
                    Text(
                      entry.formattedTimestamp,
                      style: const TextStyle(
                        color: AppColors.timestamp,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    // Response time for responses
                    if (entry.response != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${entry.response!.responseTimeMs}ms',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Message
                if (entry.message != null)
                  Text(
                    entry.message!,
                    style: TextStyle(
                      color: entry.isError ? AppColors.error : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                // HEX dump
                if (entry.rawBytes != null && entry.rawBytes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.hexDump,
                      style: const TextStyle(
                        color: AppColors.hexText,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _LogDetailSheet(entry: entry),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final text = StringBuffer();
    text.writeln('[${entry.formattedTimestamp}] ${entry.direction}');
    if (entry.message != null) text.writeln(entry.message);
    if (entry.rawBytes != null) text.writeln('HEX: ${entry.hexDump}');
    
    Clipboard.setData(ClipboardData(text: text.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log entry copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  final LogEntry entry;

  const _LogDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            'Log Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(height: 24),
          // Details
          _buildDetailRow('Timestamp', entry.timestamp.toIso8601String()),
          _buildDetailRow('Direction', entry.direction),
          _buildDetailRow('Type', entry.type.name.toUpperCase()),
          if (entry.message != null)
            _buildDetailRow('Message', entry.message!),
          if (entry.request != null) ...[
            _buildDetailRow('Slave ID', entry.request!.slaveId.toString()),
            _buildDetailRow('Function', entry.request!.functionCode.name),
            _buildDetailRow('Address', entry.request!.startAddress.toString()),
            _buildDetailRow('Quantity', entry.request!.quantity.toString()),
          ],
          if (entry.response != null) ...[
            _buildDetailRow('Success', entry.response!.success.toString()),
            _buildDetailRow('Response Time', '${entry.response!.responseTimeMs} ms'),
            if (entry.response!.errorMessage != null)
              _buildDetailRow('Error', entry.response!.errorMessage!),
            if (entry.response!.exceptionCode != null)
              _buildDetailRow('Exception', entry.response!.exceptionName),
          ],
          if (entry.rawBytes != null && entry.rawBytes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Raw Data (HEX):',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                entry.hexDump,
                style: const TextStyle(
                  color: AppColors.hexText,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.hexDump));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('HEX data copied')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy HEX'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
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
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
