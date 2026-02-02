import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Industrial-style input field with large touch targets
class IndustrialInputField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool readOnly;
  final Widget? suffix;
  final Widget? prefix;
  final int maxLines;
  final double? width;

  const IndustrialInputField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.validator,
    this.readOnly = false,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            validator: validator,
            readOnly: readOnly,
            maxLines: maxLines,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
              ),
              prefixIcon: prefix,
              suffixIcon: suffix,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric input with increment/decrement buttons
class NumericInputField extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final String? suffix;
  final double? width;
  final bool showButtons;

  const NumericInputField({
    super.key,
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 65535,
    this.step = 1,
    required this.onChanged,
    this.suffix,
    this.width,
    this.showButtons = true,
  });

  @override
  State<NumericInputField> createState() => _NumericInputFieldState();
}

class _NumericInputFieldState extends State<NumericInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(NumericInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    final newValue = (widget.value + widget.step).clamp(widget.min, widget.max);
    widget.onChanged(newValue);
  }

  void _decrement() {
    final newValue = (widget.value - widget.step).clamp(widget.min, widget.max);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (widget.showButtons)
                _buildButton(Icons.remove, _decrement, widget.value > widget.min),
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    if (intValue != null) {
                      final clampedValue = intValue.clamp(widget.min, widget.max);
                      widget.onChanged(clampedValue);
                    }
                  },
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    suffixText: widget.suffix,
                    suffixStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (widget.showButtons)
                _buildButton(Icons.add, _increment, widget.value < widget.max),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onPressed, bool enabled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: enabled ? AppColors.surfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              icon,
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown selector with industrial styling
class IndustrialDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;
  final double? width;

  const IndustrialDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.surfaceElevated,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.textSecondary,
                ),
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelBuilder(item),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// IP Address input field with validation
class IpAddressField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool>? onValidationChanged;  // Notify parent of validation state

  const IpAddressField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onValidationChanged,
  });
  
  /// Validate an IP address string
  static bool isValidIpAddress(String ip) {
    if (ip.isEmpty) return false;
    
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      if (part.isEmpty) return false;
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
    }
    
    return true;
  }

  @override
  State<IpAddressField> createState() => _IpAddressFieldState();
}

class _IpAddressFieldState extends State<IpAddressField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _isValid = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final parts = widget.value.split('.');
    _controllers = List.generate(4, (i) {
      return TextEditingController(text: i < parts.length ? parts[i] : '0');
    });
    _focusNodes = List.generate(4, (i) => FocusNode());
    _validateIp();
  }
  
  @override
  void didUpdateWidget(IpAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final parts = widget.value.split('.');
      for (int i = 0; i < 4; i++) {
        _controllers[i].text = i < parts.length ? parts[i] : '0';
      }
      _validateIp();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
  
  void _validateIp() {
    final ip = _controllers.map((c) => c.text.isEmpty ? '0' : c.text).join('.');
    final newIsValid = IpAddressField.isValidIpAddress(ip);
    
    String? newErrorMessage;
    if (!newIsValid) {
      // Check for specific errors
      final parts = ip.split('.');
      if (parts.any((p) => p.isEmpty || int.tryParse(p) == null)) {
        newErrorMessage = 'Invalid IP format';
      } else if (ip == '0.0.0.0') {
        newErrorMessage = 'IP cannot be 0.0.0.0';
      } else if (parts.any((p) => int.parse(p) > 255)) {
        newErrorMessage = 'Each octet must be 0-255';
      }
    }
    
    if (_isValid != newIsValid || _errorMessage != newErrorMessage) {
      setState(() {
        _isValid = newIsValid;
        _errorMessage = newErrorMessage;
      });
      widget.onValidationChanged?.call(newIsValid);
    }
  }

  void _updateValue() {
    final ip = _controllers.map((c) => c.text.isEmpty ? '0' : c.text).join('.');
    _validateIp();
    widget.onChanged(ip);
  }
  
  void _handleOctetChanged(int index, String value) {
    _updateValue();
    
    // Auto-advance to next field when 3 digits entered or value > 25
    if (value.length == 3 || (value.isNotEmpty && int.parse(value) > 25)) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_isValid) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 14,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isValid ? AppColors.border : AppColors.error,
              width: _isValid ? 1 : 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: List.generate(7, (index) {
              if (index.isOdd) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              final controllerIndex = index ~/ 2;
              return Expanded(
                child: TextFormField(
                  controller: _controllers[controllerIndex],
                  focusNode: _focusNodes[controllerIndex],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                    _IpOctetFormatter(),
                  ],
                  onChanged: (value) => _handleOctetChanged(controllerIndex, value),
                  style: TextStyle(
                    color: _isValid ? AppColors.textPrimary : AppColors.error,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              );
            }),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _IpOctetFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    
    final value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    if (value > 255) {
      return const TextEditingValue(
        text: '255',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
    return newValue;
  }
}
