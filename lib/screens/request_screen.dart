import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../widgets/industrial_button.dart';
import '../widgets/input_field.dart';
import '../widgets/data_display.dart';

/// Request configuration and execution screen
class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  late TextEditingController _writeValueController;

  @override
  void initState() {
    super.initState();
    _writeValueController = TextEditingController();
  }

  @override
  void dispose() {
    _writeValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection warning
                  if (!provider.isConnected)
                    _buildConnectionWarning(),
                  
                  if (!provider.isConnected) const SizedBox(height: 16),
                  
                  // Request Configuration
                  _buildRequestConfig(provider, isWide),
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  _buildActionButtons(provider),
                  const SizedBox(height: 16),
                  
                  // Polling controls
                  _buildPollingControls(provider),
                  const SizedBox(height: 16),
                  
                  // Response display
                  _buildResponseSection(provider),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConnectionWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: AppColors.warning, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Not connected. Go to Connect tab to establish connection.',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestConfig(ModbusProvider provider, bool isWide) {
    final request = provider.currentRequest;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'REQUEST CONFIGURATION',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Slave ID and Function Code row
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: NumericInputField(
                    label: 'Slave ID',
                    value: request.slaveId,
                    min: 1,
                    max: 247,
                    onChanged: (value) {
                      provider.updateRequest(request.copyWith(slaveId: value));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: IndustrialDropdown<ModbusFunctionCode>(
                    label: 'Function Code',
                    value: request.functionCode,
                    items: ModbusFunctionCode.values,
                    labelBuilder: (fc) => '${fc.shortName} - ${fc.name}',
                    onChanged: (value) {
                      if (value != null) {
                        provider.updateRequest(request.copyWith(functionCode: value));
                      }
                    },
                  ),
                ),
              ],
            )
          else ...[
            NumericInputField(
              label: 'Slave ID',
              value: request.slaveId,
              min: 1,
              max: 247,
              onChanged: (value) {
                provider.updateRequest(request.copyWith(slaveId: value));
              },
            ),
            const SizedBox(height: 16),
            IndustrialDropdown<ModbusFunctionCode>(
              label: 'Function Code',
              value: request.functionCode,
              items: ModbusFunctionCode.values,
              labelBuilder: (fc) => '${fc.shortName} - ${fc.name}',
              onChanged: (value) {
                if (value != null) {
                  provider.updateRequest(request.copyWith(functionCode: value));
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          
          // Address and Quantity row
          Row(
            children: [
              Expanded(
                child: NumericInputField(
                  label: 'Start Address',
                  value: request.startAddress,
                  min: 0,
                  max: 65535,
                  onChanged: (value) {
                    provider.updateRequest(request.copyWith(startAddress: value));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NumericInputField(
                  label: 'Quantity',
                  value: request.quantity,
                  min: 1,
                  max: 125,
                  onChanged: (value) {
                    provider.updateRequest(request.copyWith(quantity: value));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Data format options
          Row(
            children: [
              Expanded(
                child: IndustrialDropdown<DataFormat>(
                  label: 'Data Format',
                  value: request.dataFormat,
                  items: DataFormat.values,
                  labelBuilder: (df) => df.displayName,
                  onChanged: (value) {
                    if (value != null) {
                      provider.updateRequest(request.copyWith(dataFormat: value));
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: IndustrialDropdown<ByteOrder>(
                  label: 'Byte Order',
                  value: request.byteOrder,
                  items: ByteOrder.values,
                  labelBuilder: (bo) => bo.shortName,
                  onChanged: (value) {
                    if (value != null) {
                      provider.updateRequest(request.copyWith(byteOrder: value));
                    }
                  },
                ),
              ),
            ],
          ),
          
          // Write value input (if write function)
          if (request.functionCode.isWriteFunction) ...[
            const SizedBox(height: 16),
            _buildWriteValueInput(provider, request),
          ],
        ],
      ),
    );
  }

  Widget _buildWriteValueInput(ModbusProvider provider, ModbusRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Write Values',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.fcWrite.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter values separated by comma (e.g., 100, 200, 300)',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _writeValueController,
                style: const TextStyle(
                  color: AppColors.dataValue,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  hintText: '0, 0, 0...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  final values = value
                      .split(',')
                      .map((s) => int.tryParse(s.trim()) ?? 0)
                      .toList();
                  provider.updateRequest(request.copyWith(writeValues: values));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ModbusProvider provider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: IndustrialButton(
            label: 'SEND REQUEST',
            icon: Icons.send,
            isLoading: provider.isRequestInProgress,
            onPressed: provider.isConnected && !provider.isRequestInProgress
                ? () => provider.sendRequest()
                : null,
            activeColor: AppColors.success,
            minHeight: 64,
          ),
        ),
        const SizedBox(width: 12),
        ActionButton(
          icon: Icons.bookmark_add,
          tooltip: 'Save to Profile',
          onPressed: provider.activeProfile != null
              ? () => _saveRequestToProfile(provider)
              : null,
          size: 64,
        ),
      ],
    );
  }

  Widget _buildPollingControls(ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.isPollingEnabled 
              ? AppColors.warning 
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.repeat,
                color: provider.isPollingEnabled ? AppColors.warning : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'AUTO POLLING',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (provider.isPollingEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interval: ${provider.pollingIntervalMs} ms',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: AppColors.surfaceLight,
                        thumbColor: AppColors.accent,
                        overlayColor: AppColors.accent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: provider.pollingIntervalMs.toDouble(),
                        min: 100,
                        max: 10000,
                        divisions: 99,
                        onChanged: provider.isPollingEnabled 
                            ? null 
                            : (value) {
                                provider.setPollingInterval(value.toInt());
                              },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '100ms',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '10s',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IndustrialButton(
                label: provider.isPollingEnabled ? 'STOP' : 'START',
                icon: provider.isPollingEnabled ? Icons.stop : Icons.play_arrow,
                isActive: provider.isPollingEnabled,
                activeColor: AppColors.warning,
                onPressed: provider.isConnected
                    ? () {
                        if (provider.isPollingEnabled) {
                          provider.stopPolling();
                        } else {
                          provider.startPolling();
                        }
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponseSection(ModbusProvider provider) {
    final response = provider.lastResponse;
    final request = provider.currentRequest;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.output, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'RESPONSE',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            if (response != null)
              Text(
                'Last: ${response.timestamp.hour.toString().padLeft(2, '0')}:${response.timestamp.minute.toString().padLeft(2, '0')}:${response.timestamp.second.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.timestamp,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Response summary
        ResponseSummaryCard(
          response: response,
          request: request,
        ),
        
        // Data table
        if (response != null && response.success && response.rawData != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: RegisterDataTable(
              startAddress: request.startAddress,
              rawData: response.rawData,
              interpretedData: response.interpretedData,
              dataFormat: request.dataFormat,
            ),
          ),
        ],
      ],
    );
  }

  void _saveRequestToProfile(ModbusProvider provider) async {
    await provider.addRequestToProfile(provider.currentRequest);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request saved to profile'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
