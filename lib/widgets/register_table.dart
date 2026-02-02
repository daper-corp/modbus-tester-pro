import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/register_model.dart';

/// Advanced register data table with sorting, filtering, and editing
class AdvancedRegisterTable extends StatefulWidget {
  final List<RegisterValue> registers;
  final Function(RegisterDefinition, dynamic)? onValueEdit;
  final Function(RegisterDefinition)? onWatchlistToggle;
  final Function(RegisterDefinition)? onRegisterTap;
  final bool showActions;
  final bool editable;

  const AdvancedRegisterTable({
    super.key,
    required this.registers,
    this.onValueEdit,
    this.onWatchlistToggle,
    this.onRegisterTap,
    this.showActions = true,
    this.editable = false,
  });

  @override
  State<AdvancedRegisterTable> createState() => _AdvancedRegisterTableState();
}

class _AdvancedRegisterTableState extends State<AdvancedRegisterTable> {
  String _searchQuery = '';
  _SortColumn _sortColumn = _SortColumn.address;
  bool _sortAscending = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RegisterValue> get _filteredAndSortedRegisters {
    var filtered = widget.registers.where((r) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return r.definition.name.toLowerCase().contains(query) ||
          r.definition.address.toString().contains(query) ||
          r.formattedValue.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      switch (_sortColumn) {
        case _SortColumn.address:
          comparison = a.definition.address.compareTo(b.definition.address);
          break;
        case _SortColumn.name:
          comparison = a.definition.name.compareTo(b.definition.name);
          break;
        case _SortColumn.value:
          final aVal = a.currentValue is num ? a.currentValue as num : 0;
          final bVal = b.currentValue is num ? b.currentValue as num : 0;
          comparison = aVal.compareTo(bVal);
          break;
        case _SortColumn.quality:
          comparison = a.quality.compareTo(b.quality);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        _buildToolbar(),
        const SizedBox(height: 8),
        // Table header
        _buildHeader(),
        const Divider(height: 1, color: AppColors.border),
        // Table content
        Expanded(
          child: _filteredAndSortedRegisters.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredAndSortedRegisters.length,
                  itemBuilder: (context, index) {
                    return _RegisterRow(
                      register: _filteredAndSortedRegisters[index],
                      onEdit: widget.editable ? widget.onValueEdit : null,
                      onWatchlistToggle: widget.onWatchlistToggle,
                      onTap: widget.onRegisterTap,
                      showActions: widget.showActions,
                      isEven: index.isEven,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search registers...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_filteredAndSortedRegisters.length} / ${widget.registers.length}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppColors.surfaceLight,
      child: Row(
        children: [
          _buildHeaderCell('Address', _SortColumn.address, flex: 2),
          _buildHeaderCell('Name', _SortColumn.name, flex: 3),
          _buildHeaderCell('Value', _SortColumn.value, flex: 3),
          _buildHeaderCell('Quality', _SortColumn.quality, flex: 1),
          if (widget.showActions) const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, _SortColumn column, {int flex = 1}) {
    final isActive = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_sortColumn == column) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = column;
              _sortAscending = true;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.accent : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: AppColors.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.table_rows,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No registers match "$_searchQuery"'
                : 'No registers to display',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RegisterRow extends StatelessWidget {
  final RegisterValue register;
  final Function(RegisterDefinition, dynamic)? onEdit;
  final Function(RegisterDefinition)? onWatchlistToggle;
  final Function(RegisterDefinition)? onTap;
  final bool showActions;
  final bool isEven;

  const _RegisterRow({
    required this.register,
    this.onEdit,
    this.onWatchlistToggle,
    this.onTap,
    this.showActions = true,
    this.isEven = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = register.hasError;
    final hasChanged = register.hasChanged;
    final isValid = register.isValid;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () => onTap!(register.definition) : null,
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.error.withValues(alpha: 0.1)
                : isEven
                    ? Colors.transparent
                    : AppColors.surfaceLight.withValues(alpha: 0.3),
            border: Border(
              left: BorderSide(
                width: 3,
                color: hasError
                    ? AppColors.error
                    : hasChanged
                        ? AppColors.warning
                        : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: [
              // Address
              Expanded(
                flex: 2,
                child: Text(
                  register.definition.address.toString().padLeft(5, '0'),
                  style: const TextStyle(
                    color: AppColors.registerAddress,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              // Name
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      register.definition.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (register.definition.description.isNotEmpty)
                      Text(
                        register.definition.description,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Value
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (hasChanged)
                      Icon(
                        register.changeDirection > 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: register.changeDirection > 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        register.formattedValue,
                        style: TextStyle(
                          color: hasError
                              ? AppColors.error
                              : !isValid
                                  ? AppColors.warning
                                  : AppColors.dataValue,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Quality
              Expanded(
                flex: 1,
                child: _QualityIndicator(quality: register.quality),
              ),
              // Actions
              if (showActions)
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          color: AppColors.textMuted,
                          onPressed: () => _showEditDialog(context),
                        ),
                      if (onWatchlistToggle != null)
                        IconButton(
                          icon: Icon(
                            register.definition.isWatchlisted
                                ? Icons.star
                                : Icons.star_border,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          color: register.definition.isWatchlisted
                              ? AppColors.warning
                              : AppColors.textMuted,
                          onPressed: () =>
                              onWatchlistToggle!(register.definition),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final text = '${register.definition.address}: ${register.formattedValue}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(
      text: register.currentValue?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Edit ${register.definition.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Address: ${register.definition.address}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Value',
                hintText: 'Enter value',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ??
                  double.tryParse(controller.text);
              if (value != null && onEdit != null) {
                onEdit!(register.definition, value);
              }
              Navigator.pop(context);
            },
            child: const Text('Write'),
          ),
        ],
      ),
    );
  }
}

class _QualityIndicator extends StatelessWidget {
  final int quality;

  const _QualityIndicator({required this.quality});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (quality >= 90) {
      color = AppColors.success;
    } else if (quality >= 70) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$quality%',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

enum _SortColumn { address, name, value, quality }
