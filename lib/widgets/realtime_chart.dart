import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';
import '../models/register_model.dart';

/// Real-time line chart for register value trending
class RealtimeChart extends StatefulWidget {
  final List<RegisterHistoryEntry> data;
  final String title;
  final String? unit;
  final Color lineColor;
  final double? minY;
  final double? maxY;
  final int maxDataPoints;
  final bool showGrid;
  final bool showLabels;
  final bool animate;

  const RealtimeChart({
    super.key,
    required this.data,
    this.title = '',
    this.unit,
    this.lineColor = AppColors.accent,
    this.minY,
    this.maxY,
    this.maxDataPoints = 60,
    this.showGrid = true,
    this.showLabels = true,
    this.animate = true,
  });

  @override
  State<RealtimeChart> createState() => _RealtimeChartState();
}

class _RealtimeChartState extends State<RealtimeChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    if (widget.animate) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(RealtimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.length != oldWidget.data.length && widget.animate) {
      _animationController.forward(from: 0.8);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (widget.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.lineColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (widget.data.isNotEmpty)
                    Text(
                      _formatValue(widget.data.last.value),
                      style: TextStyle(
                        color: widget.lineColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _ChartPainter(
                      data: widget.data,
                      lineColor: widget.lineColor,
                      minY: widget.minY,
                      maxY: widget.maxY,
                      showGrid: widget.showGrid,
                      showLabels: widget.showLabels,
                      animationValue: _animation.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is double) {
      if (value.abs() >= 1000) {
        return '${(value / 1000).toStringAsFixed(1)}k';
      }
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }
}

class _ChartPainter extends CustomPainter {
  final List<RegisterHistoryEntry> data;
  final Color lineColor;
  final double? minY;
  final double? maxY;
  final bool showGrid;
  final bool showLabels;
  final double animationValue;

  _ChartPainter({
    required this.data,
    required this.lineColor,
    this.minY,
    this.maxY,
    this.showGrid = true,
    this.showLabels = true,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final leftPadding = showLabels ? 45.0 : 10.0;
    final bottomPadding = showLabels ? 25.0 : 10.0;
    final chartWidth = size.width - leftPadding - 10;
    final chartHeight = size.height - bottomPadding - 10;

    // Calculate Y range
    final values = data.map((e) => e.value is num ? (e.value as num).toDouble() : 0.0).toList();
    final dataMinY = values.reduce((double a, double b) => math.min(a, b));
    final dataMaxY = values.reduce((double a, double b) => math.max(a, b));
    final rangeY = (maxY ?? dataMaxY) - (minY ?? dataMinY);
    final effectiveMinY = minY ?? (dataMinY - rangeY * 0.1);
    final effectiveMaxY = maxY ?? (dataMaxY + rangeY * 0.1);
    final effectiveRangeY = effectiveMaxY - effectiveMinY;

    // Draw grid
    if (showGrid) {
      _drawGrid(canvas, size, leftPadding, bottomPadding, chartWidth, chartHeight,
          effectiveMinY, effectiveMaxY);
    }

    // Draw line
    _drawLine(canvas, leftPadding, bottomPadding, chartWidth, chartHeight,
        effectiveMinY, effectiveRangeY);

    // Draw current value marker
    if (data.isNotEmpty) {
      _drawCurrentValueMarker(canvas, leftPadding, bottomPadding, chartWidth,
          chartHeight, effectiveMinY, effectiveRangeY);
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'No data',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2,
          size.height / 2 - textPainter.height / 2),
    );
  }

  void _drawGrid(Canvas canvas, Size size, double leftPadding, double bottomPadding,
      double chartWidth, double chartHeight, double minY, double maxY) {
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = 10 + chartHeight * (1 - i / 4);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      if (showLabels) {
        final value = minY + (maxY - minY) * i / 4;
        final textPainter = TextPainter(
          text: TextSpan(
            text: _formatAxisValue(value),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
      }
    }

    // Vertical grid lines
    for (int i = 0; i <= 4; i++) {
      final x = leftPadding + chartWidth * i / 4;
      canvas.drawLine(
        Offset(x, 10),
        Offset(x, 10 + chartHeight),
        gridPaint,
      );
    }
  }

  void _drawLine(Canvas canvas, double leftPadding, double bottomPadding,
      double chartWidth, double chartHeight, double minY, double rangeY) {
    if (data.length < 2) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.3 * animationValue),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPadding, 10, chartWidth, chartHeight));

    final linePath = Path();
    final fillPath = Path();

    final visibleData = data.length > 60 ? data.sublist(data.length - 60) : data;
    final step = chartWidth / (visibleData.length - 1);

    for (int i = 0; i < visibleData.length; i++) {
      final value = visibleData[i].value is num
          ? visibleData[i].value.toDouble()
          : 0.0;
      final x = leftPadding + step * i;
      final normalizedY = rangeY != 0 ? (value - minY) / rangeY : 0.5;
      final y = 10 + chartHeight * (1 - normalizedY) * animationValue;

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, 10 + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(leftPadding + chartWidth, 10 + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  void _drawCurrentValueMarker(Canvas canvas, double leftPadding, double bottomPadding,
      double chartWidth, double chartHeight, double minY, double rangeY) {
    final lastValue = data.last.value is num ? data.last.value.toDouble() : 0.0;
    final normalizedY = rangeY != 0 ? (lastValue - minY) / rangeY : 0.5;
    final y = 10 + chartHeight * (1 - normalizedY);

    // Glow effect
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(leftPadding + chartWidth, y), 8, glowPaint);

    // Marker
    final markerPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(leftPadding + chartWidth, y), 5, markerPaint);

    final innerPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(leftPadding + chartWidth, y), 2, innerPaint);
  }

  String _formatAxisValue(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    } else if (value.abs() < 1 && value != 0) {
      return value.toStringAsFixed(2);
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        animationValue != oldDelegate.animationValue;
  }
}

/// Mini sparkline chart for compact display
class SparklineChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double width;

  const SparklineChart({
    super.key,
    required this.data,
    this.color = AppColors.accent,
    this.height = 30,
    this.width = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _SparklinePainter(data: data, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;

    final path = Path();
    final step = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = step * i;
      final normalized = range != 0 ? (data[i] - minVal) / range : 0.5;
      final y = size.height * (1 - normalized);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return data != oldDelegate.data;
  }
}

// StatsDisplay has been moved to stats_display.dart
// Use: import '../widgets/stats_display.dart';
