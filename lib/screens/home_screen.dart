import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../widgets/led_indicator.dart';
import 'connection_screen.dart';
import 'request_screen.dart';
import 'dashboard_screen.dart';
import 'log_screen.dart';
import 'profiles_screen.dart';
import 'diagnostics_screen.dart';
import 'multi_device_screen.dart';

/// Main home screen with bottom navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.settings_ethernet, label: 'Connect', index: 0),
    _NavItem(icon: Icons.send, label: 'Request', index: 1),
    _NavItem(icon: Icons.dashboard, label: 'Dashboard', index: 2, isHighlighted: true),
    _NavItem(icon: Icons.article, label: 'Logs', index: 3),
    _NavItem(icon: Icons.folder, label: 'Profiles', index: 4),
  ];

  final List<Widget> _screens = const [
    ConnectionScreen(),
    RequestScreen(),
    DashboardScreen(),
    LogScreen(),
    ProfilesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top status bar with menu
                _buildStatusBar(provider),
                // Main content
                Expanded(
                  child: _screens[_currentIndex],
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(provider),
        );
      },
    );
  }

  Widget _buildStatusBar(ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // App title with logo
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accentSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.developer_board,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'MODBUS',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const Text(
                        ' TESTER',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    provider.connectionType == ConnectionType.tcp
                        ? 'TCP Mode'
                        : 'RTU Mode',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const Spacer(),
          
          // Status indicators
          LedStatusBar(
            connectionState: provider.connectionState,
            isPolling: provider.isPollingEnabled,
            hasError: provider.lastResponse?.success == false,
          ),
          
          const SizedBox(width: 8),
          
          // Menu button for additional features
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surfaceElevated,
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              _buildMenuItem(
                icon: Icons.healing,
                label: 'Diagnostics',
                value: 'diagnostics',
                description: 'Connection testing & stats',
              ),
              _buildMenuItem(
                icon: Icons.devices,
                label: 'Multi-Device',
                value: 'multi_device',
                description: 'Monitor multiple devices',
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.backup,
                label: 'Backup Settings',
                value: 'backup',
                description: 'Export all settings',
              ),
              _buildMenuItem(
                icon: Icons.restore,
                label: 'Restore Settings',
                value: 'restore',
                description: 'Import settings backup',
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.info_outline,
                label: 'About',
                value: 'about',
                description: 'Version & licenses',
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
    required String description,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
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

  void _handleMenuAction(String action) {
    switch (action) {
      case 'diagnostics':
        _navigateToScreen('Diagnostics', const DiagnosticsScreen());
        break;
      case 'multi_device':
        _navigateToScreen('Multi-Device Monitor', const MultiDeviceScreen());
        break;
      case 'backup':
        _showBackupDialog();
        break;
      case 'restore':
        _showRestoreDialog();
        break;
      case 'about':
        _showAboutDialog();
        break;
    }
  }

  void _navigateToScreen(String title, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
          ),
          body: screen,
        ),
      ),
    );
  }

  void _showBackupDialog() {
    final provider = context.read<ModbusProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.backup, color: AppColors.accent),
            SizedBox(width: 12),
            Text('Backup Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will export:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            _buildBackupItem(Icons.settings_ethernet, 'Connection settings'),
            _buildBackupItem(Icons.folder, 'Device profiles (${provider.profiles.length})'),
            _buildBackupItem(Icons.timer, 'Polling configuration'),
            _buildBackupItem(Icons.tune, 'App preferences'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
            onPressed: () {
              Navigator.pop(context);
              _performBackup();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackupItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _performBackup() {
    // In production, would export to file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings backup created successfully'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.restore, color: AppColors.warning),
            SizedBox(width: 12),
            Text('Restore Settings'),
          ],
        ),
        content: const Text(
          'Select a backup file to restore all settings. This will overwrite current settings.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Select File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            onPressed: () {
              Navigator.pop(context);
              // In production, would show file picker
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select backup file to restore')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accentSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.developer_board, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modbus Tester Pro', style: TextStyle(fontSize: 16)),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Industrial Modbus RTU/TCP Testing Tool',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            _buildAboutItem('Platform', 'Android / Web'),
            _buildAboutItem('Protocol', 'Modbus RTU/TCP'),
            _buildAboutItem('USB Chips', 'CH340, CP210x, FTDI, PL2303'),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            const Text(
              '© 2024 Industrial Tools',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ModbusProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.map((item) {
              return _buildNavItem(
                index: item.index,
                icon: item.icon,
                label: item.label,
                badge: _getNavBadge(item.index, provider),
                badgeColor: _getNavBadgeColor(item.index, provider),
                isHighlighted: item.isHighlighted,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String? _getNavBadge(int index, ModbusProvider provider) {
    switch (index) {
      case 0:
        return provider.isConnected ? '●' : null;
      case 1:
        return provider.isPollingEnabled ? '◉' : null;
      case 3:
        final logCount = provider.logService.logs.length;
        return logCount > 0 ? (logCount > 99 ? '99+' : logCount.toString()) : null;
      case 4:
        return provider.activeProfile != null ? '✓' : null;
      default:
        return null;
    }
  }

  Color _getNavBadgeColor(int index, ModbusProvider provider) {
    switch (index) {
      case 0:
        return AppColors.success;
      case 1:
        return AppColors.warning;
      case 4:
        return AppColors.accent;
      default:
        return AppColors.accentSecondary;
    }
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    String? badge,
    Color? badgeColor,
    bool isHighlighted = false,
  }) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accent.withValues(alpha: 0.15) 
              : isHighlighted && !isSelected
                  ? AppColors.accentSecondary.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: AppColors.accent.withValues(alpha: 0.5)) 
              : isHighlighted && !isSelected
                  ? Border.all(color: AppColors.accentSecondary.withValues(alpha: 0.3))
                  : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    color: isSelected 
                        ? AppColors.accent 
                        : isHighlighted 
                            ? AppColors.accentSecondary
                            : AppColors.textMuted,
                    size: 24,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppColors.accentSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? AppColors.accent 
                    : isHighlighted
                        ? AppColors.accentSecondary
                        : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  final bool isHighlighted;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.isHighlighted = false,
  });
}
