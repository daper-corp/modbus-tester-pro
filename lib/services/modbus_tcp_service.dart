import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/modbus_models.dart';
import '../utils/data_converter.dart';
import 'modbus_service.dart';

/// Production-grade Modbus TCP Service with full error handling
class ModbusTcpServiceEnhanced implements ModbusService {
  final TcpConnectionSettings settings;
  Socket? _socket;
  int _transactionId = 0;
  
  final _connectionStateController = StreamController<ModbusConnectionState>.broadcast();
  ModbusConnectionState _connectionState = ModbusConnectionState.disconnected;
  
  // Connection management
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const int _keepAliveIntervalMs = 30000;
  
  // Current slave ID for keep-alive (can be updated dynamically)
  int _keepAliveSlaveId = 1;
  
  // Request queue for sequential processing
  final _requestQueue = <_QueuedRequest>[];
  bool _isProcessingQueue = false;
  
  // Response buffer for fragmented responses
  final List<int> _responseBuffer = [];
  Completer<List<int>>? _responseCompleter;
  
  ModbusTcpServiceEnhanced({required this.settings});
  
  @override
  ModbusConnectionState get connectionState => _connectionState;
  @override
  Stream<ModbusConnectionState> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected => _connectionState == ModbusConnectionState.connected;
  
  /// Set the slave ID to use for keep-alive requests
  void setKeepAliveSlaveId(int slaveId) {
    if (slaveId >= 1 && slaveId <= 247) {
      _keepAliveSlaveId = slaveId;
    }
  }
  
  void _setConnectionState(ModbusConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
    }
  }
  
  /// Connect with auto-reconnect support
  @override
  Future<bool> connect({bool autoReconnect = true}) async {
    if (_connectionState == ModbusConnectionState.connected) return true;
    
    _setConnectionState(ModbusConnectionState.connecting);
    _reconnectAttempts = 0;
    
    try {
      _socket = await Socket.connect(
        settings.ipAddress,
        settings.port,
        timeout: Duration(milliseconds: settings.connectionTimeout),
      );
      
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      
      // Listen for data
      _socket!.listen(
        _onDataReceived,
        onError: (error) => _handleConnectionError(error, autoReconnect),
        onDone: () => _handleConnectionClosed(autoReconnect),
        cancelOnError: false,
      );
      
      _setConnectionState(ModbusConnectionState.connected);
      _startKeepAlive();
      
      return true;
    } catch (e) {
      _setConnectionState(ModbusConnectionState.error);
      if (autoReconnect) {
        _scheduleReconnect();
      }
      return false;
    }
  }
  
  void _onDataReceived(Uint8List data) {
    _responseBuffer.addAll(data);
    
    // Check if we have a complete MBAP header (7 bytes)
    if (_responseBuffer.length >= 7) {
      final length = (_responseBuffer[4] << 8) | _responseBuffer[5];
      final totalLength = 6 + length; // MBAP header (6) + PDU
      
      if (_responseBuffer.length >= totalLength) {
        final response = _responseBuffer.sublist(0, totalLength);
        _responseBuffer.removeRange(0, totalLength);
        _responseCompleter?.complete(response);
      }
    }
  }
  
  void _handleConnectionError(dynamic error, bool autoReconnect) {
    _setConnectionState(ModbusConnectionState.error);
    _responseCompleter?.completeError(error);
    
    if (autoReconnect) {
      _scheduleReconnect();
    }
  }
  
  void _handleConnectionClosed(bool autoReconnect) {
    _setConnectionState(ModbusConnectionState.disconnected);
    _stopKeepAlive();
    
    if (autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (_reconnectAttempts + 1) * 2); // Exponential backoff
    
    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      await connect(autoReconnect: true);
    });
  }
  
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    if (!settings.keepAlive) return;
    
    _keepAliveTimer = Timer.periodic(
      const Duration(milliseconds: _keepAliveIntervalMs),
      (_) => _sendKeepAlive(),
    );
  }
  
  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }
  
  Future<void> _sendKeepAlive() async {
    if (!isConnected) return;
    
    try {
      // Send a simple read request as keep-alive using current slave ID
      await sendRequest(ModbusRequest(
        slaveId: _keepAliveSlaveId,
        functionCode: ModbusFunctionCode.readHoldingRegisters,
        startAddress: 0,
        quantity: 1,
      ));
    } catch (_) {
      // Ignore keep-alive errors - connection loss will be detected by socket listener
    }
  }
  
  /// Disconnect and cleanup
  @override
  Future<void> disconnect() async {
    _stopKeepAlive();
    _reconnectTimer?.cancel();
    _requestQueue.clear();
    
    await _socket?.close();
    _socket = null;
    _setConnectionState(ModbusConnectionState.disconnected);
  }
  
  /// Send Modbus request with retry support
  @override
  Future<ModbusResponse> sendRequest(
    ModbusRequest request, {
    int retries = 2,
    int retryDelayMs = 100,
  }) async {
    final completer = Completer<ModbusResponse>();
    
    _requestQueue.add(_QueuedRequest(
      request: request,
      completer: completer,
      retries: retries,
      retryDelayMs: retryDelayMs,
    ));
    
    _processQueue();
    
    return completer.future;
  }
  
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _requestQueue.isEmpty) return;
    
    _isProcessingQueue = true;
    
    while (_requestQueue.isNotEmpty) {
      final queuedRequest = _requestQueue.removeAt(0);
      final response = await _executeRequest(queuedRequest);
      queuedRequest.completer.complete(response);
    }
    
    _isProcessingQueue = false;
  }
  
  Future<ModbusResponse> _executeRequest(_QueuedRequest queuedRequest) async {
    int attempts = 0;
    ModbusResponse? lastResponse;
    
    while (attempts <= queuedRequest.retries) {
      if (attempts > 0) {
        await Future.delayed(Duration(milliseconds: queuedRequest.retryDelayMs));
      }
      
      lastResponse = await _sendSingleRequest(queuedRequest.request);
      
      if (lastResponse.success) {
        return lastResponse;
      }
      
      // Don't retry on exception responses (device returned error)
      if (lastResponse.exceptionCode != null) {
        return lastResponse;
      }
      
      attempts++;
    }
    
    return lastResponse ?? ModbusResponse.error(
      message: 'Request failed after ${queuedRequest.retries + 1} attempts',
      responseTimeMs: 0,
    );
  }
  
  Future<ModbusResponse> _sendSingleRequest(ModbusRequest request) async {
    final stopwatch = Stopwatch()..start();
    
    if (_socket == null || !isConnected) {
      return ModbusResponse.error(
        message: 'Not connected',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
    
    try {
      // Build and send frame
      final pdu = _buildPdu(request);
      final mbap = _buildMbapHeader(pdu.length, request.slaveId);
      final frame = Uint8List.fromList([...mbap, ...pdu]);
      
      // Setup response completer
      _responseBuffer.clear();
      _responseCompleter = Completer<List<int>>();
      
      _socket!.add(frame);
      await _socket!.flush();
      
      // Wait for response with timeout
      final response = await _responseCompleter!.future.timeout(
        Duration(milliseconds: settings.responseTimeout),
        onTimeout: () => throw TimeoutException('Response timeout'),
      );
      
      stopwatch.stop();
      return _parseResponse(response, request, stopwatch.elapsedMilliseconds);
      
    } on TimeoutException {
      stopwatch.stop();
      return ModbusResponse.error(
        message: 'Response timeout (${settings.responseTimeout}ms)',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ModbusResponse.error(
        message: 'Communication error: $e',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      _responseCompleter = null;
    }
  }
  
  List<int> _buildMbapHeader(int pduLength, int unitId) {
    _transactionId = (_transactionId + 1) & 0xFFFF;
    return [
      (_transactionId >> 8) & 0xFF,
      _transactionId & 0xFF,
      0x00, 0x00, // Protocol ID
      ((pduLength + 1) >> 8) & 0xFF,
      (pduLength + 1) & 0xFF,
      unitId & 0xFF,
    ];
  }
  
  List<int> _buildPdu(ModbusRequest request) {
    final pdu = <int>[request.functionCode.code];
    
    pdu.add((request.startAddress >> 8) & 0xFF);
    pdu.add(request.startAddress & 0xFF);
    
    if (request.functionCode.isReadFunction) {
      pdu.add((request.quantity >> 8) & 0xFF);
      pdu.add(request.quantity & 0xFF);
    } else if (request.functionCode == ModbusFunctionCode.writeSingleCoil) {
      final value = (request.writeValues?.isNotEmpty ?? false) && request.writeValues![0] != 0
          ? 0xFF00 : 0x0000;
      pdu.add((value >> 8) & 0xFF);
      pdu.add(value & 0xFF);
    } else if (request.functionCode == ModbusFunctionCode.writeSingleRegister) {
      final value = request.writeValues?.isNotEmpty ?? false ? request.writeValues![0] : 0;
      pdu.add((value >> 8) & 0xFF);
      pdu.add(value & 0xFF);
    } else if (request.functionCode == ModbusFunctionCode.writeMultipleCoils) {
      pdu.add((request.quantity >> 8) & 0xFF);
      pdu.add(request.quantity & 0xFF);
      final byteCount = (request.quantity + 7) ~/ 8;
      pdu.add(byteCount);
      for (int i = 0; i < byteCount; i++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final coilIndex = i * 8 + bit;
          if (coilIndex < (request.writeValues?.length ?? 0) &&
              request.writeValues![coilIndex] != 0) {
            byte |= (1 << bit);
          }
        }
        pdu.add(byte);
      }
    } else if (request.functionCode == ModbusFunctionCode.writeMultipleRegisters) {
      pdu.add((request.quantity >> 8) & 0xFF);
      pdu.add(request.quantity & 0xFF);
      pdu.add(request.quantity * 2);
      for (int i = 0; i < request.quantity; i++) {
        final value = i < (request.writeValues?.length ?? 0) ? request.writeValues![i] : 0;
        pdu.add((value >> 8) & 0xFF);
        pdu.add(value & 0xFF);
      }
    }
    
    return pdu;
  }
  
  ModbusResponse _parseResponse(List<int> data, ModbusRequest request, int responseTimeMs) {
    if (data.length < 9) {
      return ModbusResponse.error(
        message: 'Response too short (${data.length} bytes)',
        responseTimeMs: responseTimeMs,
      );
    }
    
    // Verify transaction ID
    final rxTransactionId = (data[0] << 8) | data[1];
    if (rxTransactionId != _transactionId) {
      return ModbusResponse.error(
        message: 'Transaction ID mismatch (expected $_transactionId, got $rxTransactionId)',
        responseTimeMs: responseTimeMs,
      );
    }
    
    final functionCode = data[7];
    
    // Check for exception response
    if (functionCode & 0x80 != 0) {
      return ModbusResponse.error(
        message: 'Modbus exception',
        exceptionCode: data.length > 8 ? data[8] : null,
        responseTimeMs: responseTimeMs,
      );
    }
    
    // Extract data
    List<int> rawData = [];
    
    if (request.functionCode.isReadFunction) {
      if (data.length < 9) {
        return ModbusResponse.error(
          message: 'Invalid response length',
          responseTimeMs: responseTimeMs,
        );
      }
      final byteCount = data[8];
      if (data.length < 9 + byteCount) {
        return ModbusResponse.error(
          message: 'Incomplete response data',
          responseTimeMs: responseTimeMs,
        );
      }
      rawData = data.sublist(9, 9 + byteCount);
    } else {
      rawData = data.sublist(8);
    }
    
    // Convert to register values
    List<int> registers = [];
    if (request.functionCode == ModbusFunctionCode.readCoils ||
        request.functionCode == ModbusFunctionCode.readDiscreteInputs) {
      for (final byte in rawData) {
        for (int i = 0; i < 8; i++) {
          registers.add((byte >> i) & 1);
        }
      }
      registers = registers.take(request.quantity).toList();
    } else if (request.functionCode.isReadFunction) {
      for (int i = 0; i < rawData.length - 1; i += 2) {
        registers.add((rawData[i] << 8) | rawData[i + 1]);
      }
    }
    
    final interpreted = request.functionCode.isReadFunction
        ? DataConverter.convertRegisters(registers, request.dataFormat, request.byteOrder)
        : null;
    
    return ModbusResponse.success(
      rawData: registers,
      interpretedData: interpreted,
      responseTimeMs: responseTimeMs,
    );
  }
  
  /// Read multiple non-contiguous registers efficiently
  Future<Map<int, ModbusResponse>> readMultipleAddresses(
    int slaveId,
    List<int> addresses,
    ModbusFunctionCode functionCode,
    DataFormat dataFormat,
    ByteOrder byteOrder,
  ) async {
    final results = <int, ModbusResponse>{};
    
    // Group contiguous addresses for efficiency
    addresses.sort();
    final groups = <List<int>>[];
    List<int> currentGroup = [];
    
    for (final addr in addresses) {
      if (currentGroup.isEmpty || addr - currentGroup.last <= 10) {
        currentGroup.add(addr);
      } else {
        groups.add(currentGroup);
        currentGroup = [addr];
      }
    }
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }
    
    // Read each group
    for (final group in groups) {
      final startAddr = group.first;
      final quantity = group.last - startAddr + dataFormat.registerCount;
      
      final response = await sendRequest(ModbusRequest(
        slaveId: slaveId,
        functionCode: functionCode,
        startAddress: startAddr,
        quantity: quantity,
        dataFormat: dataFormat,
        byteOrder: byteOrder,
      ));
      
      // Map individual addresses from response
      if (response.success && response.rawData != null) {
        for (final addr in group) {
          final offset = addr - startAddr;
          if (offset < response.rawData!.length) {
            results[addr] = ModbusResponse.success(
              rawData: [response.rawData![offset]],
              interpretedData: response.interpretedData != null && offset < response.interpretedData!.length
                  ? [response.interpretedData![offset]]
                  : null,
              responseTimeMs: response.responseTimeMs,
            );
          }
        }
      } else {
        for (final addr in group) {
          results[addr] = response;
        }
      }
    }
    
    return results;
  }
  
  @override
  void dispose() {
    disconnect();
    _connectionStateController.close();
  }
}

class _QueuedRequest {
  final ModbusRequest request;
  final Completer<ModbusResponse> completer;
  final int retries;
  final int retryDelayMs;
  
  _QueuedRequest({
    required this.request,
    required this.completer,
    this.retries = 2,
    this.retryDelayMs = 100,
  });
}
