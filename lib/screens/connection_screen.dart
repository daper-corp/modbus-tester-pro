import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../widgets/led_indicator.dart';
import '../widgets/industrial_button.dart';
import '../widgets/input_field.dart';

/// Connection settings screen
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _timeoutController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ModbusProvider>();
    _ipController = TextEditingController(text: provider.tcpSettings.ipAddress);
    _portController = TextEditingController(text: provider.tcpSettings.port.toString());
    _timeoutController = TextEditingController(text: provider.tcpSettings.responseTimeout.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status Card
              _buildConnectionStatusCard(provider),
              const SizedBox(height: 24),
              
              // Connection Type Selector
              _buildConnectionTypeSelector(provider),
              const SizedBox(height: 24),
              
              // Settings based on connection type
              if (provider.connectionType == ConnectionType.tcp)
                _buildTcpSettings(provider)
              else
                _buildRtuSettings(provider),
              
              const SizedBox(height: 32),
              
              // Connect/Disconnect Button
              _buildConnectButton(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatusCard(ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.panelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LedIndicator(
                state: provider.connectionState,
                size: 32,
                showLabel: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.isConnected) ...[
            Text(
              provider.connectionType == ConnectionType.tcp
                  ? '${provider.tcpSettings.ipAddress}:${provider.tcpSettings.port}'
                  : '${provider.rtuSettings.portName} (${provider.rtuSettings.settingsSummary})',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
          ] else if (provider.connectionState == ModbusConnectionState.error) ...[
            const Text(
              'Connection Failed',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionTypeSelector(ModbusProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONNECTION TYPE',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: IndustrialButton(
                label: 'Modbus TCP',
                icon: Icons.wifi,
                isActive: provider.connectionType == ConnectionType.tcp,
                onPressed: provider.isConnected 
                    ? null 
                    : () => provider.setConnectionType(ConnectionType.tcp),
                activeColor: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: IndustrialButton(
                label: 'Modbus RTU',
                icon: Icons.usb,
                isActive: provider.connectionType == ConnectionType.rtu,
                onPressed: provider.isConnected 
                    ? null 
                    : () => provider.setConnectionType(ConnectionType.rtu),
                activeColor: AppColors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTcpSettings(ModbusProvider provider) {
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
              Icon(Icons.settings, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'TCP SETTINGS',
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
          
          IpAddressField(
            label: 'IP Address',
            value: provider.tcpSettings.ipAddress,
            onChanged: (value) {
              provider.updateTcpSettings(
                provider.tcpSettings.copyWith(ipAddress: value),
              );
            },
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: NumericInputField(
                  label: 'Port',
                  value: provider.tcpSettings.port,
                  min: 1,
                  max: 65535,
                  onChanged: (value) {
                    provider.updateTcpSettings(
                      provider.tcpSettings.copyWith(port: value),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NumericInputField(
                  label: 'Timeout (ms)',
                  value: provider.tcpSettings.responseTimeout,
                  min: 100,
                  max: 30000,
                  step: 100,
                  suffix: 'ms',
                  onChanged: (value) {
                    provider.updateTcpSettings(
                      provider.tcpSettings.copyWith(responseTimeout: value),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: NumericInputField(
                  label: 'Connection Timeout',
                  value: provider.tcpSettings.connectionTimeout,
                  min: 1000,
                  max: 60000,
                  step: 1000,
                  suffix: 'ms',
                  onChanged: (value) {
                    provider.updateTcpSettings(
                      provider.tcpSettings.copyWith(connectionTimeout: value),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRtuSettings(ModbusProvider provider) {
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
              Icon(Icons.settings, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'RTU SETTINGS (USB SERIAL)',
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
          
          // Port selector (simulation for web)
          IndustrialDropdown<String>(
            label: 'Serial Port',
            value: provider.rtuSettings.portName.isEmpty 
                ? '/dev/ttyUSB0' 
                : provider.rtuSettings.portName,
            items: const [
              '/dev/ttyUSB0',
              '/dev/ttyUSB1',
              '/dev/ttyACM0',
              'COM1',
              'COM3',
            ],
            labelBuilder: (port) => port,
            onChanged: (value) {
              if (value != null) {
                provider.updateRtuSettings(
                  provider.rtuSettings.copyWith(portName: value),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          
          IndustrialDropdown<int>(
            label: 'Baud Rate',
            value: provider.rtuSettings.baudRate,
            items: BaudRates.all,
            labelBuilder: (rate) => '$rate bps',
            onChanged: (value) {
              if (value != null) {
                provider.updateRtuSettings(
                  provider.rtuSettings.copyWith(baudRate: value),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: IndustrialDropdown<DataBits>(
                  label: 'Data Bits',
                  value: provider.rtuSettings.dataBits,
                  items: DataBits.values,
                  labelBuilder: (db) => db.value.toString(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.updateRtuSettings(
                        provider.rtuSettings.copyWith(dataBits: value),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IndustrialDropdown<Parity>(
                  label: 'Parity',
                  value: provider.rtuSettings.parity,
                  items: Parity.values,
                  labelBuilder: (p) => p.displayName,
                  onChanged: (value) {
                    if (value != null) {
                      provider.updateRtuSettings(
                        provider.rtuSettings.copyWith(parity: value),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IndustrialDropdown<StopBits>(
                  label: 'Stop Bits',
                  value: provider.rtuSettings.stopBits,
                  items: StopBits.values,
                  labelBuilder: (sb) => sb.displayName,
                  onChanged: (value) {
                    if (value != null) {
                      provider.updateRtuSettings(
                        provider.rtuSettings.copyWith(stopBits: value),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          NumericInputField(
            label: 'Response Timeout',
            value: provider.rtuSettings.responseTimeout,
            min: 100,
            max: 30000,
            step: 100,
            suffix: 'ms',
            onChanged: (value) {
              provider.updateRtuSettings(
                provider.rtuSettings.copyWith(responseTimeout: value),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Supported chips info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supported USB-Serial Chips:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: UsbChipType.values.map((chip) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chip.name,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(ModbusProvider provider) {
    final isConnected = provider.isConnected;
    final isConnecting = provider.isConnecting;
    
    return IndustrialButton(
      label: isConnecting 
          ? 'Connecting...' 
          : isConnected 
              ? 'Disconnect' 
              : 'Connect',
      icon: isConnected ? Icons.link_off : Icons.link,
      isLoading: isConnecting,
      isActive: isConnected,
      activeColor: isConnected ? AppColors.error : AppColors.success,
      expanded: true,
      minHeight: 64,
      onPressed: isConnecting 
          ? null 
          : () async {
              if (isConnected) {
                await provider.disconnect();
              } else {
                await provider.connect();
              }
            },
    );
  }
}
