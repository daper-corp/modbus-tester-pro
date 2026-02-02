import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../models/communication_stats.dart';

import '../widgets/industrial_button.dart';

/// Multi-device monitoring screen for simultaneous device management
class MultiDeviceScreen extends StatefulWidget {
  const MultiDeviceScreen({super.key});

  @override
  State<MultiDeviceScreen> createState() => _MultiDeviceScreenState();
}

class _MultiDeviceScreenState extends State<MultiDeviceScreen> {
  final List<DeviceMonitor> _monitors = [];
  int _nextDeviceId = 1;

  @override
  void initState() {
    super.initState();
    // Add default device from current connection
    _addDeviceFromProfile();
  }

  @override
  void dispose() {
    for (final monitor in _monitors) {
      monitor.dispose();
    }
    super.dispose();
  }

  void _addDeviceFromProfile() {
    final provider = context.read<ModbusProvider>();
    
    _monitors.add(DeviceMonitor(
      id: _nextDeviceId++,
      name: 'Device ${_monitors.length + 1}',
      slaveId: 1,
      connectionType: provider.connectionType,
      tcpSettings: provider.tcpSettings,
      rtuSettings: provider.rtuSettings,
    ));
    
    setState(() {});
  }

  void _addDevice() {
    showDialog(
      context: context,
      builder: (context) => _AddDeviceDialog(
        onAdd: (name, slaveId, ipAddress, port) {
          setState(() {
            _monitors.add(DeviceMonitor(
              id: _nextDeviceId++,
              name: name,
              slaveId: slaveId,
              connectionType: ConnectionType.tcp,
              tcpSettings: TcpConnectionSettings(
                ipAddress: ipAddress,
                port: port,
              ),
            ));
          });
        },
      ),
    );
  }

  void _removeDevice(int id) {
    final monitor = _monitors.firstWhere((m) => m.id == id);
    monitor.dispose();
    setState(() {
      _monitors.removeWhere((m) => m.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Header
            _buildHeader(),
            
            // Device list
            Expanded(
              child: _monitors.isEmpty
                  ? _buildEmptyState()
                  : _buildDeviceGrid(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices, color: AppColors.accent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MULTI-DEVICE MONITORING',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${_monitors.length} device(s) configured',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          IndustrialButton(
            label: 'Add Device',
            icon: Icons.add,
            onPressed: _addDevice,
            minHeight: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.devices_other,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'No devices configured',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          IndustrialButton(
            label: 'Add First Device',
            icon: Icons.add,
            isActive: true,
            activeColor: AppColors.accent,
            onPressed: _addDevice,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _monitors.length,
      itemBuilder: (context, index) {
        return _DeviceCard(
          monitor: _monitors[index],
          onRemove: () => _removeDevice(_monitors[index].id),
          onConfigure: () => _configureDevice(_monitors[index]),
        );
      },
    );
  }

  void _configureDevice(DeviceMonitor monitor) {
    showDialog(
      context: context,
      builder: (context) => _ConfigureDeviceDialog(
        monitor: monitor,
        onUpdate: (registers) {
          setState(() {
            monitor.watchedRegisters.clear();
            monitor.watchedRegisters.addAll(registers);
          });
        },
      ),
    );
  }
}

class DeviceMonitor {
  final int id;
  String name;
  int slaveId;
  ConnectionType connectionType;
  TcpConnectionSettings tcpSettings;
  RtuConnectionSettings? rtuSettings;
  
  bool isConnected = false;
  bool isPolling = false;
  int pollingInterval = 1000;
  
  CommunicationStats stats = CommunicationStats(startTime: DateTime.now());
  List<WatchedRegister> watchedRegisters = [];
  Timer? _pollingTimer;
  
  DeviceMonitor({
    required this.id,
    required this.name,
    required this.slaveId,
    required this.connectionType,
    TcpConnectionSettings? tcpSettings,
    this.rtuSettings,
  }) : tcpSettings = tcpSettings ?? const TcpConnectionSettings() {
    // Add default watched registers
    watchedRegisters.addAll([
      WatchedRegister(
        name: 'Holding Reg 0',
        address: 0,
        functionCode: ModbusFunctionCode.readHoldingRegisters,
      ),
      WatchedRegister(
        name: 'Holding Reg 1',
        address: 1,
        functionCode: ModbusFunctionCode.readHoldingRegisters,
      ),
    ]);
  }
  
  void startPolling(Future<ModbusResponse?> Function(ModbusRequest) sendRequest) {
    if (isPolling) return;
    
    isPolling = true;
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: pollingInterval),
      (_) => _pollRegisters(sendRequest),
    );
    _pollRegisters(sendRequest);
  }
  
  void stopPolling() {
    isPolling = false;
    _pollingTimer?.cancel();
  }
  
  Future<void> _pollRegisters(Future<ModbusResponse?> Function(ModbusRequest) sendRequest) async {
    for (final reg in watchedRegisters) {
      final request = ModbusRequest(
        slaveId: slaveId,
        functionCode: reg.functionCode,
        startAddress: reg.address,
        quantity: 1,
        dataFormat: reg.dataFormat,
      );
      
      final response = await sendRequest(request);
      
      if (response != null) {
        reg.lastValue = response.interpretedData?.isNotEmpty == true
            ? response.interpretedData!.first
            : null;
        reg.lastUpdate = DateTime.now();
        reg.hasError = !response.success;
        
        stats = stats.recordRequest(
          response.success,
          response.responseTimeMs,
        );
      }
    }
  }
  
  void dispose() {
    _pollingTimer?.cancel();
  }
}

class WatchedRegister {
  final String name;
  final int address;
  final ModbusFunctionCode functionCode;
  final DataFormat dataFormat;
  
  dynamic lastValue;
  DateTime? lastUpdate;
  bool hasError = false;
  
  WatchedRegister({
    required this.name,
    required this.address,
    required this.functionCode,
    this.dataFormat = DataFormat.uint16,
  });
}

class _DeviceCard extends StatefulWidget {
  final DeviceMonitor monitor;
  final VoidCallback onRemove;
  final VoidCallback onConfigure;

  const _DeviceCard({
    required this.monitor,
    required this.onRemove,
    required this.onConfigure,
  });

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  @override
  Widget build(BuildContext context) {
    final monitor = widget.monitor;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: monitor.isConnected ? AppColors.success : AppColors.border,
          width: monitor.isConnected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: monitor.isConnected
                        ? (monitor.isPolling ? AppColors.ledOn : AppColors.success)
                        : AppColors.ledOff,
                    shape: BoxShape.circle,
                    boxShadow: monitor.isConnected
                        ? [
                            BoxShadow(
                              color: AppColors.ledOn.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    monitor.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                  color: AppColors.surfaceElevated,
                  onSelected: (value) {
                    if (value == 'configure') {
                      widget.onConfigure();
                    } else if (value == 'remove') {
                      widget.onRemove();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'configure',
                      child: Row(
                        children: [
                          Icon(Icons.settings, size: 18),
                          SizedBox(width: 8),
                          Text('Configure'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Remove', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Connection info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monitor.connectionType == ConnectionType.tcp
                      ? '${monitor.tcpSettings.ipAddress}:${monitor.tcpSettings.port}'
                      : monitor.rtuSettings?.portName ?? 'Serial',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Slave ID: ${monitor.slaveId}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: AppColors.border),
          
          // Registers
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: monitor.watchedRegisters.length,
              itemBuilder: (context, index) {
                final reg = monitor.watchedRegisters[index];
                return _buildRegisterRow(reg);
              },
            ),
          ),
          
          // Actions
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: monitor.isPolling ? Icons.stop : Icons.play_arrow,
                    label: monitor.isPolling ? 'Stop' : 'Start',
                    color: monitor.isPolling ? AppColors.error : AppColors.success,
                    onPressed: () {
                      final provider = context.read<ModbusProvider>();
                      setState(() {
                        if (monitor.isPolling) {
                          monitor.stopPolling();
                        } else {
                          monitor.isConnected = true;
                          monitor.startPolling(provider.sendRequest);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.refresh,
                    label: 'Poll',
                    onPressed: () async {
                      final provider = context.read<ModbusProvider>();
                      setState(() => monitor.isConnected = true);
                      await monitor._pollRegisters(provider.sendRequest);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterRow(WatchedRegister reg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: reg.hasError
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            reg.address.toString().padLeft(5, '0'),
            style: const TextStyle(
              color: AppColors.registerAddress,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reg.name,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            reg.lastValue?.toString() ?? '-',
            style: TextStyle(
              color: reg.hasError ? AppColors.error : AppColors.dataValue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? AppColors.accent).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color ?? AppColors.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDeviceDialog extends StatefulWidget {
  final Function(String name, int slaveId, String ipAddress, int port) onAdd;

  const _AddDeviceDialog({required this.onAdd});

  @override
  State<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<_AddDeviceDialog> {
  final _nameController = TextEditingController(text: 'New Device');
  final _slaveIdController = TextEditingController(text: '1');
  final _ipController = TextEditingController(text: '192.168.1.1');
  final _portController = TextEditingController(text: '502');

  @override
  void dispose() {
    _nameController.dispose();
    _slaveIdController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text('Add Device'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField('Device Name', _nameController),
          const SizedBox(height: 12),
          _buildTextField('Slave ID', _slaveIdController, isNumber: true),
          const SizedBox(height: 12),
          _buildTextField('IP Address', _ipController),
          const SizedBox(height: 12),
          _buildTextField('Port', _portController, isNumber: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAdd(
              _nameController.text,
              int.tryParse(_slaveIdController.text) ?? 1,
              _ipController.text,
              int.tryParse(_portController.text) ?? 502,
            );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        filled: true,
        fillColor: AppColors.surfaceLight,
      ),
    );
  }
}

class _ConfigureDeviceDialog extends StatefulWidget {
  final DeviceMonitor monitor;
  final Function(List<WatchedRegister>) onUpdate;

  const _ConfigureDeviceDialog({
    required this.monitor,
    required this.onUpdate,
  });

  @override
  State<_ConfigureDeviceDialog> createState() => _ConfigureDeviceDialogState();
}

class _ConfigureDeviceDialogState extends State<_ConfigureDeviceDialog> {
  late List<WatchedRegister> _registers;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _registers = List.from(widget.monitor.watchedRegisters);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _addRegister() {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) return;
    
    setState(() {
      _registers.add(WatchedRegister(
        name: _nameController.text,
        address: int.tryParse(_addressController.text) ?? 0,
        functionCode: ModbusFunctionCode.readHoldingRegisters,
      ));
      _nameController.clear();
      _addressController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text('Configure ${widget.monitor.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WATCHED REGISTERS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            
            // Add register form
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Name',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _addressController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Address',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.success),
                  onPressed: _addRegister,
                ),
              ],
            ),
            
            const Divider(color: AppColors.border),
            
            // Register list
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _registers.length,
                itemBuilder: (context, index) {
                  final reg = _registers[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      reg.address.toString().padLeft(5, '0'),
                      style: const TextStyle(
                        color: AppColors.registerAddress,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    title: Text(
                      reg.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                      onPressed: () {
                        setState(() => _registers.removeAt(index));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate(_registers);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
