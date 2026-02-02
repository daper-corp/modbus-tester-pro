import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Large touch-friendly industrial-style button
class IndustrialButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isActive;
  final Color? activeColor;
  final double minHeight;
  final double minWidth;
  final bool expanded;

  const IndustrialButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isActive = false,
    this.activeColor,
    this.minHeight = 56,
    this.minWidth = 120,
    this.expanded = false,
  });

  @override
  State<IndustrialButton> createState() => _IndustrialButtonState();
}

class _IndustrialButtonState extends State<IndustrialButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.activeColor ?? AppColors.accent;
    
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onPressed != null ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        constraints: BoxConstraints(
          minHeight: widget.minHeight,
          minWidth: widget.expanded ? double.infinity : widget.minWidth,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isPressed
                ? [
                    AppColors.surfaceLight.withValues(alpha: 0.8),
                    AppColors.surface,
                  ]
                : widget.isActive
                    ? [
                        effectiveColor.withValues(alpha: 0.3),
                        effectiveColor.withValues(alpha: 0.1),
                      ]
                    : [
                        AppColors.surfaceElevated,
                        AppColors.surfaceLight,
                      ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isActive ? effectiveColor : AppColors.border,
            width: widget.isActive ? 2 : 1,
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: effectiveColor,
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  color: widget.isActive ? effectiveColor : AppColors.textPrimary,
                  size: 24,
                ),
              if ((widget.icon != null || widget.isLoading) && widget.label.isNotEmpty)
                const SizedBox(width: 8),
              if (widget.label.isNotEmpty)
                Flexible(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isActive ? effectiveColor : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact action button for toolbars
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final double size;

  const ActionButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? AppColors.accent;
    
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive 
                  ? effectiveColor.withValues(alpha: 0.2) 
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? effectiveColor : AppColors.border,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? effectiveColor : AppColors.textSecondary,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggle button group for mode selection
class ToggleButtonGroup extends StatelessWidget {
  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double itemHeight;

  const ToggleButtonGroup({
    super.key,
    required this.labels,
    this.icons,
    required this.selectedIndex,
    required this.onChanged,
    this.itemHeight = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: Container(
              height: itemHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : null,
                borderRadius: BorderRadius.horizontal(
                  left: index == 0 ? const Radius.circular(7) : Radius.zero,
                  right: index == labels.length - 1 ? const Radius.circular(7) : Radius.zero,
                ),
                border: isSelected
                    ? Border.all(color: AppColors.accent, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icons != null && index < icons!.length) ...[
                    Icon(
                      icons![index],
                      color: isSelected ? AppColors.accent : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
