import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/modbus_models.dart';

/// LED-style connection status indicator
class LedIndicator extends StatefulWidget {
  final ModbusConnectionState state;
  final double size;
  final bool showLabel;
  final bool animated;

  const LedIndicator({
    super.key,
    required this.state,
    this.size = 24,
    this.showLabel = true,
    this.animated = true,
  });

  @override
  State<LedIndicator> createState() => _LedIndicatorState();
}

class _LedIndicatorState extends State<LedIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    if (widget.animated && widget.state == ModbusConnectionState.connecting) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LedIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.state == ModbusConnectionState.connecting && widget.animated) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _ledColor {
    switch (widget.state) {
      case ModbusConnectionState.connected:
        return AppColors.ledOn;
      case ModbusConnectionState.connecting:
        return AppColors.ledConnecting;
      case ModbusConnectionState.error:
        return AppColors.ledError;
      case ModbusConnectionState.disconnected:
        return AppColors.ledOff;
    }
  }

  Color get _glowColor {
    switch (widget.state) {
      case ModbusConnectionState.connected:
        return AppColors.ledOn.withValues(alpha: 0.6);
      case ModbusConnectionState.connecting:
        return AppColors.ledConnecting.withValues(alpha: 0.6);
      case ModbusConnectionState.error:
        return AppColors.ledError.withValues(alpha: 0.6);
      case ModbusConnectionState.disconnected:
        return Colors.transparent;
    }
  }

  String get _statusText {
    switch (widget.state) {
      case ModbusConnectionState.connected:
        return 'Connected';
      case ModbusConnectionState.connecting:
        return 'Connecting...';
      case ModbusConnectionState.error:
        return 'Error';
      case ModbusConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ledColor.withValues(alpha: _pulseAnimation.value),
                border: Border.all(
                  color: AppColors.metallicLight,
                  width: 2,
                ),
                boxShadow: widget.state != ModbusConnectionState.disconnected
                    ? [
                        BoxShadow(
                          color: _glowColor.withValues(alpha: _pulseAnimation.value * 0.8),
                          blurRadius: widget.size * 0.5,
                          spreadRadius: widget.size * 0.1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Container(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 8),
          Text(
            _statusText,
            style: TextStyle(
              color: _ledColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

/// Multi-LED status bar
class LedStatusBar extends StatelessWidget {
  final ModbusConnectionState connectionState;
  final bool isPolling;
  final bool hasError;

  const LedStatusBar({
    super.key,
    required this.connectionState,
    this.isPolling = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLedItem('PWR', true, AppColors.ledOn),
          const SizedBox(width: 16),
          _buildLedItem(
            'LINK',
            connectionState == ModbusConnectionState.connected,
            connectionState == ModbusConnectionState.connecting
                ? AppColors.ledConnecting
                : connectionState == ModbusConnectionState.connected
                    ? AppColors.ledOn
                    : AppColors.ledOff,
          ),
          const SizedBox(width: 16),
          _buildLedItem(
            'TX/RX',
            isPolling,
            isPolling ? AppColors.ledWarning : AppColors.ledOff,
          ),
          const SizedBox(width: 16),
          _buildLedItem(
            'ERR',
            hasError,
            hasError ? AppColors.ledError : AppColors.ledOff,
          ),
        ],
      ),
    );
  }

  Widget _buildLedItem(String label, bool active, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : AppColors.ledOff,
            border: Border.all(color: AppColors.metallicLight, width: 1),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
