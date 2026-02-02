import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/communication_stats.dart';

/// Communication statistics display widget
class StatsDisplay extends StatelessWidget {
  final CommunicationStats stats;
  final bool compact;
  
  const StatsDisplay({
    super.key,
    required this.stats,
    this.compact = false,
  });
  
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactStats();
    }
    return _buildFullStats();
  }
  
  Widget _buildCompactStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactStat(
            'OK',
            '${stats.successRate.toStringAsFixed(0)}%',
            _getSuccessRateColor(stats.successRate),
          ),
          const SizedBox(width: 16),
          _buildCompactStat(
            'AVG',
            '${stats.averageResponseTime.toStringAsFixed(0)}ms',
            _getResponseTimeColor(stats.averageResponseTime),
          ),
          const SizedBox(width: 16),
          _buildCompactStat(
            'REQ',
            stats.totalRequests.toString(),
            AppColors.textPrimary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
  
  Widget _buildFullStats() {
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
              _buildQualityIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMUNICATION QUALITY',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats.quality.displayName,
                      style: TextStyle(
                        color: _getQualityColor(stats.quality),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildUptimeDisplay(),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          
          // Main statistics grid
          Row(
            children: [
              Expanded(child: _buildStatCard('Success Rate', '${stats.successRate.toStringAsFixed(1)}%', _getSuccessRateColor(stats.successRate))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Total Requests', stats.totalRequests.toString(), AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Avg Response', '${stats.averageResponseTime.toStringAsFixed(1)}ms', _getResponseTimeColor(stats.averageResponseTime))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Failed', stats.failedRequests.toString(), stats.failedRequests > 0 ? AppColors.error : AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Min/Max', '${stats.minResponseTime}/${stats.maxResponseTime}ms', AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Jitter', '${stats.jitter.toStringAsFixed(1)}ms', AppColors.textSecondary)),
            ],
          ),
          
          if (stats.timeoutCount > 0 || stats.crcErrorCount > 0 || stats.exceptionCount > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            
            // Error breakdown
            const Text(
              'ERROR BREAKDOWN',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildErrorChip('Timeouts', stats.timeoutCount, AppColors.warning),
                const SizedBox(width: 8),
                _buildErrorChip('CRC Errors', stats.crcErrorCount, AppColors.error),
                const SizedBox(width: 8),
                _buildErrorChip('Exceptions', stats.exceptionCount, AppColors.fcWrite),
              ],
            ),
          ],
          
          // Response time trend mini chart
          if (stats.responseTimes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'RESPONSE TIME TREND',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: _buildMiniTrendChart(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildQualityIndicator() {
    final quality = stats.quality;
    final color = _getQualityColor(quality);
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          quality.grade,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildUptimeDisplay() {
    final uptime = stats.uptime;
    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;
    final seconds = uptime.inSeconds % 60;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'UPTIME',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
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
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? color.withValues(alpha: 0.2) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: count > 0 ? color : AppColors.border,
        ),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: count > 0 ? color : AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildMiniTrendChart() {
    final trend = stats.getRecentTrend(60);
    if (trend.isEmpty) return const SizedBox();
    
    final maxValue = trend.reduce((a, b) => a > b ? a : b).toDouble();
    final minValue = trend.reduce((a, b) => a < b ? a : b).toDouble();
    final range = maxValue - minValue;
    
    return CustomPaint(
      painter: _TrendChartPainter(
        data: trend.map((e) => e.toDouble()).toList(),
        minValue: minValue,
        maxValue: range > 0 ? maxValue : maxValue + 10,
        lineColor: AppColors.accent,
        fillColor: AppColors.accent.withValues(alpha: 0.2),
      ),
      size: const Size(double.infinity, 60),
    );
  }
  
  Color _getSuccessRateColor(double rate) {
    if (rate >= 99) return AppColors.success;
    if (rate >= 95) return AppColors.ledOn;
    if (rate >= 90) return AppColors.warning;
    return AppColors.error;
  }
  
  Color _getResponseTimeColor(double time) {
    if (time < 50) return AppColors.success;
    if (time < 100) return AppColors.ledOn;
    if (time < 200) return AppColors.warning;
    return AppColors.error;
  }
  
  Color _getQualityColor(CommunicationQuality quality) {
    switch (quality) {
      case CommunicationQuality.excellent:
        return AppColors.success;
      case CommunicationQuality.good:
        return AppColors.ledOn;
      case CommunicationQuality.fair:
        return AppColors.warning;
      case CommunicationQuality.poor:
        return AppColors.error;
      case CommunicationQuality.unknown:
        return AppColors.textMuted;
    }
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<double> data;
  final double minValue;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;
  
  _TrendChartPainter({
    required this.data,
    required this.minValue,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final range = maxValue - minValue;
    final stepX = size.width / (data.length - 1);
    
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    
    final linePath = Path();
    final fillPath = Path();
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }
  
  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
