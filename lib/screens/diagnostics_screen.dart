import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../models/communication_stats.dart';
import '../widgets/led_indicator.dart';
import '../widgets/industrial_button.dart';
import '../widgets/stats_display.dart';

/// Diagnostics and connection testing screen
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _isTestRunning = false;
  String _testStatus = 'Ready to test';
  final List<DiagnosticResult> _testResults = [];
  CommunicationStats _testStats = CommunicationStats(startTime: DateTime.now());
  
  int _pingCount = 10;
  int _testAddress = 0;
  int _testQuantity = 1;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(provider),
              const SizedBox(height: 24),
              
              // Quick Tests
              _buildQuickTests(provider),
              const SizedBox(height: 24),
              
              // Ping Test Configuration
              _buildPingTestConfig(provider),
              const SizedBox(height: 24),
              
              // Test Results
              if (_testResults.isNotEmpty) ...[
                _buildTestResults(),
                const SizedBox(height: 24),
              ],
              
              // Statistics
              _buildStatisticsSection(),
              const SizedBox(height: 24),
              
              // Connection Quality Assessment
              _buildQualityAssessment(),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildHeader(ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.panelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          LedIndicator(
            state: provider.connectionState,
            size: 24,
            showLabel: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIAGNOSTICS',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _testStatus,
                  style: TextStyle(
                    color: _isTestRunning ? AppColors.warning : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isTestRunning)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildQuickTests(ModbusProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK TESTS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildQuickTestButton(
              label: 'Ping Device',
              icon: Icons.radar,
              onPressed: provider.isConnected && !_isTestRunning
                  ? () => _runPingTest(provider)
                  : null,
            ),
            _buildQuickTestButton(
              label: 'Read Test',
              icon: Icons.download,
              onPressed: provider.isConnected && !_isTestRunning
                  ? () => _runReadTest(provider)
                  : null,
            ),
            _buildQuickTestButton(
              label: 'Stress Test',
              icon: Icons.speed,
              onPressed: provider.isConnected && !_isTestRunning
                  ? () => _runStressTest(provider)
                  : null,
            ),
            _buildQuickTestButton(
              label: 'Latency Test',
              icon: Icons.timer,
              onPressed: provider.isConnected && !_isTestRunning
                  ? () => _runLatencyTest(provider)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildQuickTestButton({
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return IndustrialButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      minWidth: 130,
      minHeight: 48,
    );
  }
  
  Widget _buildPingTestConfig(ModbusProvider provider) {
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
              Icon(Icons.settings, size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                'PING TEST CONFIGURATION',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildConfigInput(
                  label: 'Ping Count',
                  value: _pingCount,
                  onChanged: (v) => setState(() => _pingCount = v),
                  min: 1,
                  max: 100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildConfigInput(
                  label: 'Start Address',
                  value: _testAddress,
                  onChanged: (v) => setState(() => _testAddress = v),
                  min: 0,
                  max: 65535,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildConfigInput(
                  label: 'Quantity',
                  value: _testQuantity,
                  onChanged: (v) => setState(() => _testQuantity = v),
                  min: 1,
                  max: 125,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: IndustrialButton(
                  label: 'Run Configured Test',
                  icon: Icons.play_arrow,
                  expanded: true,
                  activeColor: AppColors.success,
                  isActive: true,
                  onPressed: provider.isConnected && !_isTestRunning
                      ? () => _runConfiguredTest(provider)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              IndustrialButton(
                label: 'Clear',
                icon: Icons.clear,
                onPressed: _testResults.isNotEmpty
                    ? () => setState(() {
                        _testResults.clear();
                        _testStats = CommunicationStats(startTime: DateTime.now());
                      })
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfigInput({
    required String label,
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: value > min
                    ? () => onChanged(value - 1)
                    : null,
                child: Icon(
                  Icons.remove,
                  size: 18,
                  color: value > min ? AppColors.accent : AppColors.textMuted,
                ),
              ),
              Expanded(
                child: Text(
                  value.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.dataValue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              GestureDetector(
                onTap: value < max
                    ? () => onChanged(value + 1)
                    : null,
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: value < max ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTestResults() {
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
          Row(
            children: [
              const Text(
                'TEST RESULTS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_testResults.length} tests',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[_testResults.length - 1 - index];
                return _buildResultItem(result, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultItem(DiagnosticResult result, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? AppColors.success : AppColors.error,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: result.success ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                result.success ? Icons.check : Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.testName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  result.message,
                  style: TextStyle(
                    color: result.success ? AppColors.textSecondary : AppColors.error,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.responseTimeMs}ms',
                style: TextStyle(
                  color: _getResponseTimeColor(result.responseTimeMs),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                result.timestamp.toString().substring(11, 23),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SESSION STATISTICS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        StatsDisplay(stats: _testStats),
      ],
    );
  }
  
  Widget _buildQualityAssessment() {
    final quality = _testStats.quality;
    
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
          const Text(
            'CONNECTION RECOMMENDATIONS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          
          if (_testStats.totalRequests < 10)
            _buildRecommendation(
              icon: Icons.info_outline,
              color: AppColors.accent,
              title: 'Run more tests',
              description: 'Run at least 10 tests to get meaningful statistics',
            )
          else if (quality == CommunicationQuality.excellent)
            _buildRecommendation(
              icon: Icons.check_circle,
              color: AppColors.success,
              title: 'Excellent Connection',
              description: 'Your connection is stable with fast response times',
            )
          else if (quality == CommunicationQuality.good)
            _buildRecommendation(
              icon: Icons.thumb_up,
              color: AppColors.ledOn,
              title: 'Good Connection',
              description: 'Connection is stable, suitable for production use',
            )
          else if (quality == CommunicationQuality.fair)
            _buildRecommendation(
              icon: Icons.warning,
              color: AppColors.warning,
              title: 'Fair Connection',
              description: 'Consider checking cable quality or reducing polling rate',
            )
          else
            _buildRecommendation(
              icon: Icons.error,
              color: AppColors.error,
              title: 'Poor Connection',
              description: 'Check cables, termination, and baud rate settings',
            ),
          
          if (_testStats.timeoutCount > _testStats.totalRequests * 0.1 && _testStats.totalRequests >= 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildRecommendation(
                icon: Icons.timer_off,
                color: AppColors.warning,
                title: 'High Timeout Rate',
                description: 'Increase response timeout or check device connectivity',
              ),
            ),
          
          if (_testStats.crcErrorCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildRecommendation(
                icon: Icons.error_outline,
                color: AppColors.error,
                title: 'CRC Errors Detected',
                description: 'Check cable shielding and RS485 termination',
              ),
            ),
          
          if (_testStats.jitter > 50 && _testStats.totalRequests >= 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildRecommendation(
                icon: Icons.sync_problem,
                color: AppColors.warning,
                title: 'High Jitter',
                description: 'Response times are inconsistent, check for interference',
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendation({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getResponseTimeColor(int time) {
    if (time < 50) return AppColors.success;
    if (time < 100) return AppColors.ledOn;
    if (time < 200) return AppColors.warning;
    return AppColors.error;
  }
  
  // Test methods
  Future<void> _runPingTest(ModbusProvider provider) async {
    await _runTest(
      provider: provider,
      testName: 'Ping Test',
      count: _pingCount,
    );
  }
  
  Future<void> _runReadTest(ModbusProvider provider) async {
    await _runTest(
      provider: provider,
      testName: 'Read Test',
      count: 5,
    );
  }
  
  Future<void> _runStressTest(ModbusProvider provider) async {
    await _runTest(
      provider: provider,
      testName: 'Stress Test',
      count: 50,
      delayMs: 0,
    );
  }
  
  Future<void> _runLatencyTest(ModbusProvider provider) async {
    await _runTest(
      provider: provider,
      testName: 'Latency Test',
      count: 20,
      delayMs: 100,
    );
  }
  
  Future<void> _runConfiguredTest(ModbusProvider provider) async {
    await _runTest(
      provider: provider,
      testName: 'Configured Test',
      count: _pingCount,
      startAddress: _testAddress,
      quantity: _testQuantity,
    );
  }
  
  Future<void> _runTest({
    required ModbusProvider provider,
    required String testName,
    required int count,
    int startAddress = 0,
    int quantity = 1,
    int delayMs = 50,
  }) async {
    if (_isTestRunning) return;
    
    setState(() {
      _isTestRunning = true;
      _testStatus = 'Running $testName...';
    });
    
    for (int i = 0; i < count; i++) {
      if (!mounted) break;
      
      setState(() {
        _testStatus = 'Running $testName... (${i + 1}/$count)';
      });
      
      final request = ModbusRequest(
        slaveId: 1,
        functionCode: ModbusFunctionCode.readHoldingRegisters,
        startAddress: startAddress,
        quantity: quantity,
      );
      
      final response = await provider.sendRequest(request);
      
      final result = DiagnosticResult(
        testName: '$testName #${i + 1}',
        success: response?.success ?? false,
        message: response?.success == true
            ? 'Read ${response?.rawData?.length ?? 0} registers'
            : (response?.errorMessage ?? 'No response'),
        responseTimeMs: response?.responseTimeMs ?? 0,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _testResults.add(result);
        _testStats = _testStats.recordRequest(
          result.success,
          result.responseTimeMs,
          isTimeout: response?.errorMessage?.contains('timeout') ?? false,
          isCrcError: response?.errorMessage?.contains('CRC') ?? false,
          isException: response?.exceptionCode != null,
        );
      });
      
      if (delayMs > 0 && i < count - 1) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    
    setState(() {
      _isTestRunning = false;
      _testStatus = '$testName completed';
    });
  }
}

class DiagnosticResult {
  final String testName;
  final bool success;
  final String message;
  final int responseTimeMs;
  final DateTime timestamp;
  
  DiagnosticResult({
    required this.testName,
    required this.success,
    required this.message,
    required this.responseTimeMs,
    required this.timestamp,
  });
}
