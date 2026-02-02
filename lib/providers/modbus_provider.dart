import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/modbus_models.dart';
import '../services/modbus_service.dart';
import '../services/modbus_tcp_service.dart';
import '../services/log_service.dart';
import '../services/storage_service.dart';

/// Callback type for connection state errors
typedef ConnectionErrorCallback = void Function(String error);

/// Main state provider for Modbus operations
class ModbusProvider extends ChangeNotifier {
  final LogService _logService;
  final StorageService _storageService;
  
  ModbusService? _modbusService;
  Timer? _pollingTimer;
  StreamSubscription<ModbusConnectionState>? _connectionStateSubscription;
  
  // Current slave ID for keep-alive
  int _currentSlaveId = 1;
  
  // Connection state
  ConnectionType _connectionType = ConnectionType.tcp;
  RtuConnectionSettings _rtuSettings = const RtuConnectionSettings();
  TcpConnectionSettings _tcpSettings = const TcpConnectionSettings();
  ModbusConnectionState _connectionState = ModbusConnectionState.disconnected;
  
  // Request state
  ModbusRequest _currentRequest = const ModbusRequest(
    slaveId: 1,
    functionCode: ModbusFunctionCode.readHoldingRegisters,
    startAddress: 0,
    quantity: 10,
  );
  
  ModbusResponse? _lastResponse;
  bool _isRequestInProgress = false;
  
  // Polling state
  bool _isPollingEnabled = false;
  int _pollingIntervalMs = 1000;
  
  // Profiles
  List<DeviceProfile> _profiles = [];
  DeviceProfile? _activeProfile;
  
  ModbusProvider({
    required LogService logService,
    required StorageService storageService,
  }) : _logService = logService,
       _storageService = storageService {
    _loadSavedSettings();
  }
  
  // Getters
  ConnectionType get connectionType => _connectionType;
  RtuConnectionSettings get rtuSettings => _rtuSettings;
  TcpConnectionSettings get tcpSettings => _tcpSettings;
  ModbusConnectionState get connectionState => _connectionState;
  ModbusRequest get currentRequest => _currentRequest;
  ModbusResponse? get lastResponse => _lastResponse;
  bool get isRequestInProgress => _isRequestInProgress;
  bool get isPollingEnabled => _isPollingEnabled;
  int get pollingIntervalMs => _pollingIntervalMs;
  List<DeviceProfile> get profiles => _profiles;
  DeviceProfile? get activeProfile => _activeProfile;
  LogService get logService => _logService;
  int get currentSlaveId => _currentSlaveId;
  
  bool get isConnected => _connectionState == ModbusConnectionState.connected;
  bool get isConnecting => _connectionState == ModbusConnectionState.connecting;
  
  /// Load saved settings from storage
  Future<void> _loadSavedSettings() async {
    // Load last connection settings
    final lastConnection = _storageService.getLastConnection();
    if (lastConnection != null) {
      _connectionType = ConnectionType.values.firstWhere(
        (t) => t.name == lastConnection['type'],
        orElse: () => ConnectionType.tcp,
      );
      
      if (lastConnection['rtuSettings'] != null) {
        _rtuSettings = RtuConnectionSettings.fromJson(lastConnection['rtuSettings']);
      }
      if (lastConnection['tcpSettings'] != null) {
        _tcpSettings = TcpConnectionSettings.fromJson(lastConnection['tcpSettings']);
      }
    }
    
    // Load last request
    final lastRequest = _storageService.getLastRequest();
    if (lastRequest != null) {
      _currentRequest = lastRequest;
    }
    
    // Load polling interval
    _pollingIntervalMs = _storageService.getPollingInterval();
    
    // Load profiles
    _profiles = _storageService.getAllProfiles();
    
    notifyListeners();
  }
  
  /// Set connection type
  void setConnectionType(ConnectionType type) {
    _connectionType = type;
    notifyListeners();
  }
  
  /// Update RTU settings
  void updateRtuSettings(RtuConnectionSettings settings) {
    _rtuSettings = settings;
    notifyListeners();
  }
  
  /// Update TCP settings
  void updateTcpSettings(TcpConnectionSettings settings) {
    _tcpSettings = settings;
    notifyListeners();
  }
  
  /// Connect to device
  Future<bool> connect() async {
    if (_connectionState == ModbusConnectionState.connected) {
      return true;
    }
    
    _connectionState = ModbusConnectionState.connecting;
    notifyListeners();
    
    // Create appropriate service
    if (_connectionType == ConnectionType.tcp) {
      // Use enhanced TCP service with auto-reconnect, keep-alive, and request queue
      _modbusService = ModbusTcpServiceEnhanced(settings: _tcpSettings);
      _logService.logConnection(
        'Connecting to ${_tcpSettings.ipAddress}:${_tcpSettings.port}...',
      );
    } else {
      // Use simulator for RTU in web preview
      _modbusService = ModbusRtuSimulator(settings: _rtuSettings);
      _logService.logConnection(
        'Connecting to ${_rtuSettings.portName} (${_rtuSettings.settingsSummary})...',
      );
    }
    
    // Cancel previous subscription to prevent memory leak
    await _connectionStateSubscription?.cancel();
    
    // Subscribe to connection state changes
    _connectionStateSubscription = _modbusService!.connectionStateStream.listen(
      (state) {
        _connectionState = state;
        // Auto-stop polling if disconnected
        if (state == ModbusConnectionState.disconnected || 
            state == ModbusConnectionState.error) {
          if (_isPollingEnabled) {
            stopPolling();
            _logService.logWarning('Polling stopped due to connection loss');
          }
        }
        notifyListeners();
      },
      onError: (error) {
        _logService.logError('Connection state stream error: $error');
        _connectionState = ModbusConnectionState.error;
        notifyListeners();
      },
    );
    
    final success = await _modbusService!.connect();
    
    if (success) {
      _logService.logConnection('Connected successfully');
      
      // Save connection settings
      await _storageService.saveLastConnection(
        type: _connectionType,
        rtuSettings: _rtuSettings,
        tcpSettings: _tcpSettings,
      );
    } else {
      _logService.logConnection('Connection failed', isError: true);
      _connectionState = ModbusConnectionState.error;
    }
    
    notifyListeners();
    return success;
  }
  
  /// Disconnect from device
  Future<void> disconnect() async {
    stopPolling();
    
    // Cancel connection state subscription
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    
    await _modbusService?.disconnect();
    _modbusService?.dispose();
    _modbusService = null;
    _connectionState = ModbusConnectionState.disconnected;
    _logService.logConnection('Disconnected');
    notifyListeners();
  }
  
  /// Update current request
  void updateRequest(ModbusRequest request) {
    _currentRequest = request;
    // Update slave ID for keep-alive
    _currentSlaveId = request.slaveId;
    notifyListeners();
  }
  
  /// Set current slave ID (for keep-alive)
  void setCurrentSlaveId(int slaveId) {
    _currentSlaveId = slaveId;
  }
  
  /// Send Modbus request
  Future<ModbusResponse?> sendRequest([ModbusRequest? request]) async {
    request ??= _currentRequest;
    
    if (_modbusService == null || !isConnected) {
      _logService.logError('Not connected');
      return null;
    }
    
    if (_isRequestInProgress) {
      return null;
    }
    
    _isRequestInProgress = true;
    notifyListeners();
    
    // Log the request
    List<int>? txBytes;
    if (_modbusService is ModbusRtuSimulator) {
      txBytes = (_modbusService as ModbusRtuSimulator).buildRtuFrame(request);
    }
    _logService.logRequest(request, txBytes);
    
    // Send request
    final response = await _modbusService!.sendRequest(request);
    
    // Log response
    _logService.logResponse(response, request);
    
    _lastResponse = response;
    _isRequestInProgress = false;
    
    // Save request
    await _storageService.saveLastRequest(request);
    
    notifyListeners();
    return response;
  }
  
  /// Start polling
  void startPolling() {
    if (_isPollingEnabled) return;
    
    _isPollingEnabled = true;
    _logService.logInfo('Polling started (interval: ${_pollingIntervalMs}ms)');
    
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: _pollingIntervalMs),
      (_) => sendRequest(),
    );
    
    notifyListeners();
  }
  
  /// Stop polling
  void stopPolling() {
    if (!_isPollingEnabled) return;
    
    _isPollingEnabled = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _logService.logInfo('Polling stopped');
    
    notifyListeners();
  }
  
  /// Set polling interval
  void setPollingInterval(int intervalMs) {
    _pollingIntervalMs = intervalMs.clamp(100, 10000);
    _storageService.savePollingInterval(_pollingIntervalMs);
    
    if (_isPollingEnabled) {
      stopPolling();
      startPolling();
    }
    
    notifyListeners();
  }
  
  /// Save current settings as profile
  Future<DeviceProfile> saveAsProfile(String name, String description) async {
    final profile = DeviceProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      connectionType: _connectionType,
      rtuSettings: _connectionType == ConnectionType.rtu ? _rtuSettings : null,
      tcpSettings: _connectionType == ConnectionType.tcp ? _tcpSettings : null,
      savedRequests: [_currentRequest],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _storageService.saveProfile(profile);
    _profiles = _storageService.getAllProfiles();
    _activeProfile = profile;
    
    _logService.logInfo('Profile saved: $name');
    notifyListeners();
    
    return profile;
  }
  
  /// Load profile
  void loadProfile(DeviceProfile profile) {
    _activeProfile = profile;
    _connectionType = profile.connectionType;
    
    if (profile.rtuSettings != null) {
      _rtuSettings = profile.rtuSettings!;
    }
    if (profile.tcpSettings != null) {
      _tcpSettings = profile.tcpSettings!;
    }
    if (profile.savedRequests.isNotEmpty) {
      _currentRequest = profile.savedRequests.first;
    }
    
    _logService.logInfo('Profile loaded: ${profile.name}');
    notifyListeners();
  }
  
  /// Delete profile
  Future<void> deleteProfile(String id) async {
    await _storageService.deleteProfile(id);
    _profiles = _storageService.getAllProfiles();
    
    if (_activeProfile?.id == id) {
      _activeProfile = null;
    }
    
    notifyListeners();
  }
  
  /// Add request to current profile
  Future<void> addRequestToProfile(ModbusRequest request) async {
    if (_activeProfile == null) return;
    
    final updatedProfile = _activeProfile!.copyWith(
      savedRequests: [..._activeProfile!.savedRequests, request],
    );
    
    await _storageService.saveProfile(updatedProfile);
    _activeProfile = updatedProfile;
    _profiles = _storageService.getAllProfiles();
    
    notifyListeners();
  }
  
  /// Clear logs
  void clearLogs() {
    _logService.clearLogs();
  }
  
  @override
  void dispose() {
    _pollingTimer?.cancel();
    _connectionStateSubscription?.cancel();
    _modbusService?.dispose();
    super.dispose();
  }
}
