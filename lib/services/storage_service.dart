import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/modbus_models.dart';

/// Storage operation result with error information
class StorageResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? corruptedCount;  // For getAllProfiles
  
  const StorageResult.success(this.data) 
      : success = true, errorMessage = null, corruptedCount = null;
  const StorageResult.successWithWarning(this.data, this.corruptedCount)
      : success = true, errorMessage = null;
  const StorageResult.failure(this.errorMessage) 
      : success = false, data = null, corruptedCount = null;
}

/// Service for managing local storage
class StorageService {
  static const String _profilesBoxName = 'device_profiles';
  static const String _settingsBoxName = 'app_settings';
  static const String _lastConnectionKey = 'last_connection';
  static const String _lastRequestKey = 'last_request';
  static const String _pollingIntervalKey = 'polling_interval';
  
  late Box<String> _profilesBox;
  late Box<String> _settingsBox;
  SharedPreferences? _prefs;
  
  bool _isInitialized = false;
  
  /// Initialize storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await Hive.initFlutter();
    _profilesBox = await Hive.openBox<String>(_profilesBoxName);
    _settingsBox = await Hive.openBox<String>(_settingsBoxName);
    _prefs = await SharedPreferences.getInstance();
    
    _isInitialized = true;
  }
  
  /// Save device profile
  Future<void> saveProfile(DeviceProfile profile) async {
    await _profilesBox.put(profile.id, jsonEncode(profile.toJson()));
  }
  
  /// Get all device profiles with error reporting
  StorageResult<List<DeviceProfile>> getAllProfilesWithResult() {
    final profiles = <DeviceProfile>[];
    int corruptedCount = 0;
    final corruptedKeys = <String>[];
    
    for (final key in _profilesBox.keys) {
      final json = _profilesBox.get(key);
      if (json != null) {
        try {
          profiles.add(DeviceProfile.fromJson(jsonDecode(json)));
        } catch (e) {
          corruptedCount++;
          corruptedKeys.add(key.toString());
          if (kDebugMode) {
            debugPrint('StorageService: Corrupted profile at key $key: $e');
          }
        }
      }
    }
    
    profiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    if (corruptedCount > 0) {
      return StorageResult.successWithWarning(profiles, corruptedCount);
    }
    return StorageResult.success(profiles);
  }
  
  /// Get all device profiles (legacy method for backward compatibility)
  List<DeviceProfile> getAllProfiles() {
    return getAllProfilesWithResult().data ?? [];
  }
  
  /// Clean up corrupted profiles
  Future<int> cleanCorruptedProfiles() async {
    int cleanedCount = 0;
    final keysToDelete = <String>[];
    
    for (final key in _profilesBox.keys) {
      final json = _profilesBox.get(key);
      if (json != null) {
        try {
          DeviceProfile.fromJson(jsonDecode(json));
        } catch (e) {
          keysToDelete.add(key.toString());
        }
      }
    }
    
    for (final key in keysToDelete) {
      await _profilesBox.delete(key);
      cleanedCount++;
    }
    
    return cleanedCount;
  }
  
  /// Get profile by ID with error reporting
  StorageResult<DeviceProfile> getProfileWithResult(String id) {
    final json = _profilesBox.get(id);
    if (json == null) {
      return const StorageResult.failure('Profile not found');
    }
    
    try {
      return StorageResult.success(DeviceProfile.fromJson(jsonDecode(json)));
    } catch (e) {
      return StorageResult.failure('Profile data corrupted: $e');
    }
  }
  
  /// Get profile by ID (legacy method)
  DeviceProfile? getProfile(String id) {
    return getProfileWithResult(id).data;
  }
  
  /// Delete profile
  Future<void> deleteProfile(String id) async {
    await _profilesBox.delete(id);
  }
  
  /// Save last connection settings
  Future<void> saveLastConnection({
    required ConnectionType type,
    RtuConnectionSettings? rtuSettings,
    TcpConnectionSettings? tcpSettings,
  }) async {
    final data = {
      'type': type.name,
      'rtuSettings': rtuSettings?.toJson(),
      'tcpSettings': tcpSettings?.toJson(),
    };
    await _settingsBox.put(_lastConnectionKey, jsonEncode(data));
  }
  
  /// Get last connection settings
  Map<String, dynamic>? getLastConnection() {
    final json = _settingsBox.get(_lastConnectionKey);
    if (json != null) {
      try {
        return jsonDecode(json);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Save last request
  Future<void> saveLastRequest(ModbusRequest request) async {
    await _settingsBox.put(_lastRequestKey, jsonEncode(request.toJson()));
  }
  
  /// Get last request
  ModbusRequest? getLastRequest() {
    final json = _settingsBox.get(_lastRequestKey);
    if (json != null) {
      try {
        return ModbusRequest.fromJson(jsonDecode(json));
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Save polling interval
  Future<void> savePollingInterval(int intervalMs) async {
    await _prefs?.setInt(_pollingIntervalKey, intervalMs);
  }
  
  /// Get polling interval
  int getPollingInterval() {
    return _prefs?.getInt(_pollingIntervalKey) ?? 1000;
  }
  
  /// Save any key-value setting
  Future<void> saveSetting(String key, dynamic value) async {
    if (value is String) {
      await _prefs?.setString(key, value);
    } else if (value is int) {
      await _prefs?.setInt(key, value);
    } else if (value is double) {
      await _prefs?.setDouble(key, value);
    } else if (value is bool) {
      await _prefs?.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs?.setStringList(key, value);
    } else {
      await _settingsBox.put(key, jsonEncode(value));
    }
  }
  
  /// Get string setting
  String? getStringSetting(String key) {
    return _prefs?.getString(key);
  }
  
  /// Get int setting
  int? getIntSetting(String key) {
    return _prefs?.getInt(key);
  }
  
  /// Get bool setting
  bool? getBoolSetting(String key) {
    return _prefs?.getBool(key);
  }
  
  /// Clear all data
  Future<void> clearAll() async {
    await _profilesBox.clear();
    await _settingsBox.clear();
    await _prefs?.clear();
  }
  
  /// Export all data as JSON
  String exportData() {
    final data = {
      'profiles': getAllProfiles().map((p) => p.toJson()).toList(),
      'settings': {
        'pollingInterval': getPollingInterval(),
        'lastConnection': getLastConnection(),
        'lastRequest': getLastRequest()?.toJson(),
      },
      'exportDate': DateTime.now().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
  
  /// Import data from JSON with error reporting
  Future<StorageResult<ImportResult>> importData(String jsonData) async {
    try {
      final data = jsonDecode(jsonData);
      int importedProfiles = 0;
      int failedProfiles = 0;
      final errors = <String>[];
      
      // Import profiles
      if (data['profiles'] != null) {
        for (final profileJson in data['profiles']) {
          try {
            final profile = DeviceProfile.fromJson(profileJson);
            await saveProfile(profile);
            importedProfiles++;
          } catch (e) {
            failedProfiles++;
            errors.add('Failed to import profile: $e');
          }
        }
      }
      
      // Import settings
      if (data['settings'] != null) {
        final settings = data['settings'];
        if (settings['pollingInterval'] != null) {
          await savePollingInterval(settings['pollingInterval']);
        }
      }
      
      return StorageResult.success(ImportResult(
        importedProfiles: importedProfiles,
        failedProfiles: failedProfiles,
        errors: errors,
      ));
    } catch (e) {
      return StorageResult.failure('Invalid JSON format: $e');
    }
  }
  
  void dispose() {
    _profilesBox.close();
    _settingsBox.close();
  }
}

/// Result of import operation
class ImportResult {
  final int importedProfiles;
  final int failedProfiles;
  final List<String> errors;
  
  const ImportResult({
    required this.importedProfiles,
    required this.failedProfiles,
    required this.errors,
  });
  
  bool get hasErrors => failedProfiles > 0;
  String get summary => 'Imported $importedProfiles profile(s)${failedProfiles > 0 ? ', $failedProfiles failed' : ''}';
}
