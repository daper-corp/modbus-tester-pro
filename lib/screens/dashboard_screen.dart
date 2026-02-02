import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../models/register_model.dart';
import '../models/communication_stats.dart';
import '../widgets/led_indicator.dart';
import '../widgets/realtime_chart.dart';
import '../widgets/register_table.dart';
import '../widgets/industrial_button.dart';
import '../widgets/stats_display.dart';

/// Real-time monitoring dashboard
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Demo data for watchlist
  final List<RegisterDefinition> _watchlistRegisters = [
    const RegisterDefinition(
      id: '1',
      name: 'Temperature',
      description: 'Process temperature',
      address: 0,
      dataFormat: DataFormat.float32,
      scaleFactor: 0.1,
      unit: '°C',
      minValue: -40,
      maxValue: 200,
      isWatchlisted: true,
    ),
    const RegisterDefinition(
      id: '2',
      name: 'Pressure',
      description: 'System pressure',
      address: 2,
      dataFormat: DataFormat.float32,
      scaleFactor: 0.01,
      unit: 'bar',
      minValue: 0,
      maxValue: 50,
      isWatchlisted: true,
    ),
    const RegisterDefinition(
      id: '3',
      name: 'Flow Rate',
      description: 'Flow measurement',
      address: 4,
      dataFormat: DataFormat.uint16,
      scaleFactor: 0.1,
      unit: 'L/min',
      minValue: 0,
      maxValue: 1000,
      isWatchlisted: true,
    ),
    const RegisterDefinition(
      id: '4',
      name: 'Motor Speed',
      description: 'Motor RPM',
      address: 6,
      dataFormat: DataFormat.uint16,
      unit: 'RPM',
      minValue: 0,
      maxValue: 3600,
      isWatchlisted: true,
    ),
    const RegisterDefinition(
      id: '5',
      name: 'Status',
      description: 'System status',
      address: 8,
      dataFormat: DataFormat.uint16,
      enumMapping: {
        0: 'Stopped',
        1: 'Running',
        2: 'Warning',
        3: 'Error',
      },
      isWatchlisted: true,
    ),
  ];

  // Register values with history
  Map<String, RegisterValue> _registerValues = {};
  Map<String, List<RegisterHistoryEntry>> _registerHistory = {};
  
  CommunicationStats _stats = CommunicationStats(startTime: DateTime.now());
  Timer? _pollingTimer;
  bool _isPolling = false;
  int _pollingInterval = 1000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeRegisters();
  }

  void _initializeRegisters() {
    for (final reg in _watchlistRegisters) {
      _registerValues[reg.id] = RegisterValue(
        definition: reg,
        timestamp: DateTime.now(),
      );
      _registerHistory[reg.id] = [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (_isPolling) return;
    
    setState(() => _isPolling = true);
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: _pollingInterval),
      (_) => _pollRegisters(),
    );
    _pollRegisters(); // Initial poll
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    setState(() => _isPolling = false);
  }

  Future<void> _pollRegisters() async {
    final provider = context.read<ModbusProvider>();
    if (!provider.isConnected) return;

    final stopwatch = Stopwatch()..start();
    
    for (final reg in _watchlistRegisters) {
      final response = await provider.sendRequest(ModbusRequest(
        slaveId: 1,
        functionCode: reg.functionCode,
        startAddress: reg.address,
        quantity: reg.dataFormat.registerCount,
        dataFormat: reg.dataFormat,
        byteOrder: reg.byteOrder,
      ));
      
      stopwatch.stop();
      
      setState(() {
        _stats = _stats.recordRequest(
          response?.success ?? false,
          response?.responseTimeMs ?? 0,
          isTimeout: response?.errorMessage?.contains('timeout') ?? false,
          isException: response?.exceptionCode != null,
        );

        if (response != null) {
          final oldValue = _registerValues[reg.id];
          final newValue = response.success && response.interpretedData != null
              ? response.interpretedData!.first
              : null;

          // Update history
          if (newValue != null) {
            final history = _registerHistory[reg.id] ?? [];
            history.add(RegisterHistoryEntry(
              timestamp: DateTime.now(),
              value: newValue,
              quality: response.success ? 100 : 0,
            ));
            if (history.length > 120) {
              history.removeAt(0);
            }
            _registerHistory[reg.id] = history;
          }

          _registerValues[reg.id] = RegisterValue(
            definition: reg,
            currentValue: newValue,
            previousValue: oldValue?.currentValue,
            timestamp: DateTime.now(),
            history: _registerHistory[reg.id] ?? [],
            hasError: !response.success,
            errorMessage: response.errorMessage,
            quality: response.success ? 100 : 0,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Dashboard header
            _buildHeader(provider),
            // Tab bar
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'OVERVIEW', icon: Icon(Icons.dashboard, size: 18)),
                  Tab(text: 'TRENDING', icon: Icon(Icons.show_chart, size: 18)),
                  Tab(text: 'TABLE', icon: Icon(Icons.table_chart, size: 18)),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(provider),
                  _buildTrendingTab(),
                  _buildTableTab(provider),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          LedIndicator(
            state: provider.connectionState,
            size: 20,
            showLabel: false,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MONITORING DASHBOARD',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Text(
                _isPolling ? 'Polling: ${_pollingInterval}ms' : 'Stopped',
                style: TextStyle(
                  color: _isPolling ? AppColors.success : AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Polling interval selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _pollingInterval,
                dropdownColor: AppColors.surfaceElevated,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 100, child: Text('100ms')),
                  DropdownMenuItem(value: 250, child: Text('250ms')),
                  DropdownMenuItem(value: 500, child: Text('500ms')),
                  DropdownMenuItem(value: 1000, child: Text('1s')),
                  DropdownMenuItem(value: 2000, child: Text('2s')),
                  DropdownMenuItem(value: 5000, child: Text('5s')),
                ],
                onChanged: _isPolling
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _pollingInterval = value);
                        }
                      },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IndustrialButton(
            label: _isPolling ? 'Stop' : 'Start',
            icon: _isPolling ? Icons.stop : Icons.play_arrow,
            isActive: _isPolling,
            activeColor: _isPolling ? AppColors.error : AppColors.success,
            minWidth: 100,
            minHeight: 40,
            onPressed: provider.isConnected
                ? () {
                    if (_isPolling) {
                      _stopPolling();
                    } else {
                      _startPolling();
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ModbusProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats card
          StatsDisplay(stats: _stats),
          const SizedBox(height: 16),
          // Register cards grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _watchlistRegisters.length,
            itemBuilder: (context, index) {
              final reg = _watchlistRegisters[index];
              final value = _registerValues[reg.id];
              return _buildRegisterCard(reg, value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard(RegisterDefinition reg, RegisterValue? value) {
    final hasError = value?.hasError ?? false;
    final hasChanged = value?.hasChanged ?? false;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? AppColors.error
              : hasChanged
                  ? AppColors.warning
                  : AppColors.border,
          width: hasError || hasChanged ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  reg.address.toString().padLeft(5, '0'),
                  style: const TextStyle(
                    color: AppColors.registerAddress,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              if (hasChanged)
                Icon(
                  (value?.changeDirection ?? 0) > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  size: 16,
                  color: (value?.changeDirection ?? 0) > 0
                      ? AppColors.success
                      : AppColors.error,
                ),
            ],
          ),
          const Spacer(),
          Text(
            value?.formattedValue ?? '-',
            style: TextStyle(
              color: hasError ? AppColors.error : AppColors.dataValue,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reg.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (reg.description.isNotEmpty)
            Text(
              reg.description,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _watchlistRegisters.where((reg) {
          // Only show numeric registers in trending
          return reg.dataFormat != DataFormat.ascii &&
              reg.enumMapping == null;
        }).map((reg) {
          final history = _registerHistory[reg.id] ?? [];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 200,
              child: RealtimeChart(
                data: history,
                title: '${reg.name} (${reg.unit ?? ''})',
                lineColor: _getColorForIndex(_watchlistRegisters.indexOf(reg)),
                minY: reg.minValue,
                maxY: reg.maxValue,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableTab(ModbusProvider provider) {
    final registers = _watchlistRegisters
        .map((reg) => _registerValues[reg.id])
        .whereType<RegisterValue>()
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AdvancedRegisterTable(
        registers: registers,
        showActions: true,
        editable: provider.isConnected,
        onValueEdit: (def, value) {
          // Would send write request
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Write ${def.name} = $value')),
          );
        },
        onWatchlistToggle: (def) {
          // Toggle watchlist
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Toggled watchlist for ${def.name}')),
          );
        },
      ),
    );
  }

  Color _getColorForIndex(int index) {
    const colors = [
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.fcDiagnostic,
      AppColors.fcWrite,
    ];
    return colors[index % colors.length];
  }
}
