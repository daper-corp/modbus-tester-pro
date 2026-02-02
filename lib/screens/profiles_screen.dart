import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/modbus_provider.dart';
import '../models/modbus_models.dart';
import '../widgets/industrial_button.dart';

/// Device profiles management screen
class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ModbusProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Toolbar
            _buildToolbar(context, provider),
            
            // Profiles list
            Expanded(
              child: provider.profiles.isEmpty
                  ? _buildEmptyState(context, provider)
                  : _buildProfilesList(context, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, ModbusProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          const Text(
            'DEVICE PROFILES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          IndustrialButton(
            label: 'New Profile',
            icon: Icons.add,
            minWidth: 140,
            minHeight: 44,
            onPressed: () => _showCreateProfileDialog(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ModbusProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 72,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Profiles Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Save your connection settings and frequently used\nrequests as profiles for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            IndustrialButton(
              label: 'Create First Profile',
              icon: Icons.add,
              onPressed: () => _showCreateProfileDialog(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilesList(BuildContext context, ModbusProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.profiles.length,
      itemBuilder: (context, index) {
        final profile = provider.profiles[index];
        final isActive = provider.activeProfile?.id == profile.id;
        
        return _ProfileCard(
          profile: profile,
          isActive: isActive,
          onLoad: () => provider.loadProfile(profile),
          onDelete: () => _showDeleteDialog(context, provider, profile),
          onEdit: () => _showEditProfileDialog(context, provider, profile),
        );
      },
    );
  }

  void _showCreateProfileDialog(BuildContext context, ModbusProvider provider) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Create New Profile'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Save current connection settings and request configuration as a new profile.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Profile Name',
                  hintText: 'e.g., PLC Main Controller',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Main building HVAC system',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Will save:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildWillSaveItem(
                      Icons.wifi,
                      provider.connectionType == ConnectionType.tcp
                          ? 'TCP: ${provider.tcpSettings.ipAddress}:${provider.tcpSettings.port}'
                          : 'RTU: ${provider.rtuSettings.portName}',
                    ),
                    const SizedBox(height: 4),
                    _buildWillSaveItem(
                      Icons.send,
                      '${provider.currentRequest.functionCode.shortName} @ ${provider.currentRequest.startAddress}',
                    ),
                  ],
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
              if (nameController.text.trim().isNotEmpty) {
                provider.saveAsProfile(
                  nameController.text.trim(),
                  descController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildWillSaveItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, ModbusProvider provider, DeviceProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final descController = TextEditingController(text: profile.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Edit Profile'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Profile Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
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
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                // Profile update - copyWith creates new profile instance
                // Note: would need to add an updateProfile method to provider
                // profile.copyWith(name: nameController.text.trim(), description: descController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ModbusProvider provider, DeviceProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Delete Profile'),
        content: Text(
          'Are you sure you want to delete "${profile.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteProfile(profile.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Profile card widget
class _ProfileCard extends StatelessWidget {
  final DeviceProfile profile;
  final bool isActive;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onLoad,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.border,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onLoad,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Profile icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: profile.connectionType == ConnectionType.tcp
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : AppColors.fcWrite.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        profile.connectionType == ConnectionType.tcp
                            ? Icons.wifi
                            : Icons.usb,
                        color: profile.connectionType == ConnectionType.tcp
                            ? AppColors.accent
                            : AppColors.fcWrite,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Profile info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (profile.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              profile.description,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                      color: AppColors.surfaceElevated,
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Connection details
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.link,
                      profile.connectionType == ConnectionType.tcp
                          ? '${profile.tcpSettings?.ipAddress ?? ''}:${profile.tcpSettings?.port ?? 502}'
                          : profile.rtuSettings?.portName ?? '',
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.list,
                      '${profile.savedRequests.length} requests',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Last updated
                Text(
                  'Updated: ${_formatDate(profile.updatedAt)}',
                  style: const TextStyle(
                    color: AppColors.timestamp,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
