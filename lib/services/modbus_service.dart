import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/modbus_models.dart';
import '../utils/crc16.dart';
import '../utils/data_converter.dart';

/// Abstract Modbus service interface
abstract class ModbusService {
  ModbusConnectionState get connectionState;
  Stream<ModbusConnectionState> get connectionStateStream;
  
  Future<bool> connect();
  Future<void> disconnect();
  Future<ModbusResponse> sendRequest(ModbusRequest request);
  
  void dispose();
}

/// Modbus TCP implementation
class ModbusTcpService implements ModbusService {
  final TcpConnectionSettings settings;
  Socket? _socket;
  int _transactionId = 0;
  
  final _connectionStateController = StreamController<ModbusConnectionState>.broadcast();
  ModbusConnectionState _connectionState = ModbusConnectionState.disconnected;
  
  ModbusTcpService({required this.settings});
  
  @override
  ModbusConnectionState get connectionState => _connectionState;
  
  @override
  Stream<ModbusConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  void _setModbusConnectionState(ModbusConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }
  
  @override
  Future<bool> connect() async {
    if (_connectionState == ModbusConnectionState.connected) return true;
    
    _setModbusConnectionState(ModbusConnectionState.connecting);
    
    try {
      _socket = await Socket.connect(
        settings.ipAddress,
        settings.port,
        timeout: Duration(milliseconds: settings.connectionTimeout),
      );
      
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      
      _setModbusConnectionState(ModbusConnectionState.connected);
      return true;
    } catch (e) {
      _setModbusConnectionState(ModbusConnectionState.error);
      return false;
    }
  }
  
  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _setModbusConnectionState(ModbusConnectionState.disconnected);
  }
  
  @override
  Future<ModbusResponse> sendRequest(ModbusRequest request) async {
    final stopwatch = Stopwatch()..start();
    
    if (_socket == null || _connectionState != ModbusConnectionState.connected) {
      return ModbusResponse.error(
        message: 'Not connected',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
    
    try {
      final pdu = _buildPdu(request);
      final mbap = _buildMbapHeader(pdu.length, request.slaveId);
      final frame = [...mbap, ...pdu];
      
      _socket!.add(Uint8List.fromList(frame));
      await _socket!.flush();
      
      // Wait for response
      final response = await _socket!
          .timeout(Duration(milliseconds: settings.responseTimeout))
          .first;
      
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
    }
  }
  
  List<int> _buildMbapHeader(int pduLength, int unitId) {
    _transactionId = (_transactionId + 1) & 0xFFFF;
    return [
      (_transactionId >> 8) & 0xFF, // Transaction ID High
      _transactionId & 0xFF,         // Transaction ID Low
      0x00, 0x00,                    // Protocol ID (Modbus = 0)
      ((pduLength + 1) >> 8) & 0xFF, // Length High
      (pduLength + 1) & 0xFF,        // Length Low
      unitId & 0xFF,                 // Unit Identifier
    ];
  }
  
  List<int> _buildPdu(ModbusRequest request) {
    final pdu = <int>[request.functionCode.code];
    
    // Start address (2 bytes)
    pdu.add((request.startAddress >> 8) & 0xFF);
    pdu.add(request.startAddress & 0xFF);
    
    if (request.functionCode.isReadFunction) {
      // Quantity (2 bytes)
      pdu.add((request.quantity >> 8) & 0xFF);
      pdu.add(request.quantity & 0xFF);
    } else if (request.functionCode == ModbusFunctionCode.writeSingleCoil) {
      // Value (0xFF00 for ON, 0x0000 for OFF)
      final value = (request.writeValues?.isNotEmpty ?? false) && request.writeValues![0] != 0
          ? 0xFF00 : 0x0000;
      pdu.add((value >> 8) & 0xFF);
      pdu.add(value & 0xFF);
    } else if (request.functionCode == ModbusFunctionCode.writeSingleRegister) {
      // Value (2 bytes)
      final value = request.writeValues?.isNotEmpty ?? false ? request.writeValues![0] : 0;
      pdu.add((value >> 8) & 0xFF);
      pdu.add(value & 0xFF);
    } else if (request.functionCode == ModbusFunctionCode.writeMultipleCoils) {
      // Quantity
      pdu.add((request.quantity >> 8) & 0xFF);
      pdu.add(request.quantity & 0xFF);
      // Byte count
      final byteCount = (request.quantity + 7) ~/ 8;
      pdu.add(byteCount);
      // Coil values
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
      // Quantity
      pdu.add((request.quantity >> 8) & 0xFF);
      pdu.add(request.quantity & 0xFF);
      // Byte count
      pdu.add(request.quantity * 2);
      // Register values
      for (int i = 0; i < request.quantity; i++) {
        final value = i < (request.writeValues?.length ?? 0) ? request.writeValues![i] : 0;
        pdu.add((value >> 8) & 0xFF);
        pdu.add(value & 0xFF);
      }
    }
    
    return pdu;
  }
  
  ModbusResponse _parseResponse(
    List<int> data,
    ModbusRequest request,
    int responseTimeMs,
  ) {
    if (data.length < 9) {
      return ModbusResponse.error(
        message: 'Response too short',
        responseTimeMs: responseTimeMs,
      );
    }
    
    final functionCode = data[7];
    
    // Check for exception response
    if (functionCode & 0x80 != 0) {
      return ModbusResponse.error(
        message: 'Modbus exception',
        exceptionCode: data[8],
        responseTimeMs: responseTimeMs,
      );
    }
    
    // Extract data based on function code
    List<int> rawData = [];
    
    if (request.functionCode.isReadFunction) {
      final byteCount = data[8];
      rawData = data.sublist(9, 9 + byteCount);
    } else {
      // Write response - echo back
      rawData = data.sublist(8);
    }
    
    // Convert raw bytes to register values for read functions
    List<int> registers = [];
    if (request.functionCode == ModbusFunctionCode.readCoils ||
        request.functionCode == ModbusFunctionCode.readDiscreteInputs) {
      // Bit data
      for (final byte in rawData) {
        for (int i = 0; i < 8; i++) {
          registers.add((byte >> i) & 1);
        }
      }
      registers = registers.take(request.quantity).toList();
    } else if (request.functionCode.isReadFunction) {
      // Register data
      for (int i = 0; i < rawData.length - 1; i += 2) {
        registers.add((rawData[i] << 8) | rawData[i + 1]);
      }
    }
    
    // Interpret data
    final interpreted = request.functionCode.isReadFunction
        ? DataConverter.convertRegisters(registers, request.dataFormat, request.byteOrder)
        : null;
    
    return ModbusResponse.success(
      rawData: registers,
      interpretedData: interpreted,
      responseTimeMs: responseTimeMs,
    );
  }
  
  @override
  void dispose() {
    _socket?.close();
    _connectionStateController.close();
  }
}

/// Modbus RTU simulation (for web preview - actual USB Serial requires native platform)
class ModbusRtuSimulator implements ModbusService {
  final RtuConnectionSettings settings;
  
  final _connectionStateController = StreamController<ModbusConnectionState>.broadcast();
  ModbusConnectionState _connectionState = ModbusConnectionState.disconnected;
  
  // Simulated register values for testing
  final Map<int, int> _simulatedHoldingRegisters = {};
  final Map<int, int> _simulatedInputRegisters = {};
  final Map<int, bool> _simulatedCoils = {};
  final Map<int, bool> _simulatedDiscreteInputs = {};
  
  ModbusRtuSimulator({required this.settings}) {
    // Initialize with sample data
    for (int i = 0; i < 100; i++) {
      _simulatedHoldingRegisters[i] = (i * 100) & 0xFFFF;
      _simulatedInputRegisters[i] = (1000 + i * 10) & 0xFFFF;
      _simulatedCoils[i] = i % 2 == 0;
      _simulatedDiscreteInputs[i] = i % 3 == 0;
    }
  }
  
  @override
  ModbusConnectionState get connectionState => _connectionState;
  
  @override
  Stream<ModbusConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  void _setModbusConnectionState(ModbusConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }
  
  @override
  Future<bool> connect() async {
    _setModbusConnectionState(ModbusConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 500));
    _setModbusConnectionState(ModbusConnectionState.connected);
    return true;
  }
  
  @override
  Future<void> disconnect() async {
    _setModbusConnectionState(ModbusConnectionState.disconnected);
  }
  
  @override
  Future<ModbusResponse> sendRequest(ModbusRequest request) async {
    final stopwatch = Stopwatch()..start();
    
    // Simulate communication delay
    await Future.delayed(Duration(milliseconds: 20 + (settings.responseTimeout ~/ 20)));
    
    if (_connectionState != ModbusConnectionState.connected) {
      return ModbusResponse.error(
        message: 'Not connected',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
    
    List<int> registers = [];
    
    switch (request.functionCode) {
      case ModbusFunctionCode.readCoils:
        for (int i = 0; i < request.quantity; i++) {
          registers.add(_simulatedCoils[request.startAddress + i] == true ? 1 : 0);
        }
        break;
        
      case ModbusFunctionCode.readDiscreteInputs:
        for (int i = 0; i < request.quantity; i++) {
          registers.add(_simulatedDiscreteInputs[request.startAddress + i] == true ? 1 : 0);
        }
        break;
        
      case ModbusFunctionCode.readHoldingRegisters:
        for (int i = 0; i < request.quantity; i++) {
          registers.add(_simulatedHoldingRegisters[request.startAddress + i] ?? 0);
        }
        break;
        
      case ModbusFunctionCode.readInputRegisters:
        for (int i = 0; i < request.quantity; i++) {
          registers.add(_simulatedInputRegisters[request.startAddress + i] ?? 0);
        }
        break;
        
      case ModbusFunctionCode.writeSingleCoil:
        _simulatedCoils[request.startAddress] = 
            (request.writeValues?.isNotEmpty ?? false) && request.writeValues![0] != 0;
        registers = [request.startAddress, request.writeValues?[0] ?? 0];
        break;
        
      case ModbusFunctionCode.writeSingleRegister:
        _simulatedHoldingRegisters[request.startAddress] = request.writeValues?[0] ?? 0;
        registers = [request.startAddress, request.writeValues?[0] ?? 0];
        break;
        
      case ModbusFunctionCode.writeMultipleCoils:
        for (int i = 0; i < request.quantity; i++) {
          _simulatedCoils[request.startAddress + i] = 
              i < (request.writeValues?.length ?? 0) && request.writeValues![i] != 0;
        }
        registers = [request.startAddress, request.quantity];
        break;
        
      case ModbusFunctionCode.writeMultipleRegisters:
        for (int i = 0; i < request.quantity; i++) {
          _simulatedHoldingRegisters[request.startAddress + i] = 
              i < (request.writeValues?.length ?? 0) ? request.writeValues![i] : 0;
        }
        registers = [request.startAddress, request.quantity];
        break;
        
      default:
        return ModbusResponse.error(
          message: 'Function code not supported in simulator',
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
    }
    
    stopwatch.stop();
    
    final interpreted = request.functionCode.isReadFunction
        ? DataConverter.convertRegisters(registers, request.dataFormat, request.byteOrder)
        : null;
    
    return ModbusResponse.success(
      rawData: registers,
      interpretedData: interpreted,
      responseTimeMs: stopwatch.elapsedMilliseconds,
    );
  }
  
  /// Build RTU frame (for display/logging)
  List<int> buildRtuFrame(ModbusRequest request) {
    final frame = <int>[request.slaveId, request.functionCode.code];
    
    // Start address
    frame.add((request.startAddress >> 8) & 0xFF);
    frame.add(request.startAddress & 0xFF);
    
    if (request.functionCode.isReadFunction) {
      frame.add((request.quantity >> 8) & 0xFF);
      frame.add(request.quantity & 0xFF);
    } else if (request.functionCode == ModbusFunctionCode.writeSingleRegister) {
      final value = request.writeValues?.isNotEmpty ?? false ? request.writeValues![0] : 0;
      frame.add((value >> 8) & 0xFF);
      frame.add(value & 0xFF);
    }
    
    return CRC16.appendCrc(frame);
  }
  
  @override
  void dispose() {
    _connectionStateController.close();
  }
}
