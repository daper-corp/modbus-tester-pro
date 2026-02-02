import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/modbus_models.dart';
import '../utils/data_converter.dart';

/// Register data table display
class RegisterDataTable extends StatelessWidget {
  final int startAddress;
  final List<int>? rawData;
  final List<dynamic>? interpretedData;
  final DataFormat dataFormat;
  final bool showAddress;
  final bool showRaw;

  const RegisterDataTable({
    super.key,
    required this.startAddress,
    this.rawData,
    this.interpretedData,
    this.dataFormat = DataFormat.uint16,
    this.showAddress = true,
    this.showRaw = true,
  });

  @override
  Widget build(BuildContext context) {
    if (rawData == null || rawData!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                if (showAddress)
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Address',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (showRaw)
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Raw (HEX)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Value (${dataFormat.displayName})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Data rows
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _getRowCount(),
              itemBuilder: (context, index) {
                return _buildDataRow(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getRowCount() {
    if (dataFormat.registerCount > 1 && interpretedData != null) {
      return interpretedData!.length;
    }
    return rawData?.length ?? 0;
  }

  Widget _buildDataRow(int index) {
    final address = startAddress + (index * dataFormat.registerCount);
    final rawValue = index < (rawData?.length ?? 0) ? rawData![index] : 0;
    final interpretedValue = index < (interpretedData?.length ?? 0) 
        ? interpretedData![index] 
        : rawValue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.transparent : AppColors.surfaceLight.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (showAddress)
            Expanded(
              flex: 2,
              child: Text(
                address.toString().padLeft(5, '0'),
                style: const TextStyle(
                  color: AppColors.registerAddress,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          if (showRaw)
            Expanded(
              flex: 2,
              child: Text(
                '0x${rawValue.toRadixString(16).toUpperCase().padLeft(4, '0')}',
                style: const TextStyle(
                  color: AppColors.hexText,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: interpretedValue.toString()));
              },
              child: Text(
                DataConverter.formatValue(interpretedValue, dataFormat),
                style: const TextStyle(
                  color: AppColors.dataValue,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// HEX dump display widget
class HexDumpDisplay extends StatelessWidget {
  final List<int>? bytes;
  final String? label;
  final bool showAscii;

  const HexDumpDisplay({
    super.key,
    this.bytes,
    this.label,
    this.showAscii = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (bytes == null || bytes!.isEmpty)
            const Text(
              '(empty)',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // HEX values
                  Text(
                    bytes!.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' '),
                    style: const TextStyle(
                      color: AppColors.hexText,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  if (showAscii) ...[
                    const SizedBox(width: 24),
                    Text(
                      '|',
                      style: TextStyle(color: AppColors.border),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bytes!.map((b) => b >= 32 && b <= 126 ? String.fromCharCode(b) : '.').join(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Response summary card
class ResponseSummaryCard extends StatelessWidget {
  final ModbusResponse? response;
  final ModbusRequest? request;

  const ResponseSummaryCard({
    super.key,
    this.response,
    this.request,
  });

  @override
  Widget build(BuildContext context) {
    if (response == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'Send a request to see response',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: response!.success ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                response!.success ? Icons.check_circle : Icons.error,
                color: response!.success ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                response!.success ? 'SUCCESS' : 'ERROR',
                style: TextStyle(
                  color: response!.success ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${response!.responseTimeMs} ms',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!response!.success) ...[
            Text(
              response!.errorMessage ?? 'Unknown error',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
            if (response!.exceptionCode != null) ...[
              const SizedBox(height: 4),
              Text(
                'Exception: ${response!.exceptionName}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            Text(
              'Received ${response!.rawData?.length ?? 0} values',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              response!.formattedTimestamp,
              style: const TextStyle(
                color: AppColors.timestamp,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on ModbusResponse {
  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}.'
           '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }
}
