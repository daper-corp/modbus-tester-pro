import 'package:equatable/equatable.dart';

/// Connection type enum
enum ConnectionType { rtu, tcp }

/// Modbus Function Codes
enum ModbusFunctionCode {
  readCoils(0x01, 'Read Coils', 'FC01'),
  readDiscreteInputs(0x02, 'Read Discrete Inputs', 'FC02'),
  readHoldingRegisters(0x03, 'Read Holding Registers', 'FC03'),
  readInputRegisters(0x04, 'Read Input Registers', 'FC04'),
  writeSingleCoil(0x05, 'Write Single Coil', 'FC05'),
  writeSingleRegister(0x06, 'Write Single Register', 'FC06'),
  writeMultipleCoils(0x0F, 'Write Multiple Coils', 'FC15'),
  writeMultipleRegisters(0x10, 'Write Multiple Registers', 'FC16'),
  readWriteMultipleRegisters(0x17, 'Read/Write Multiple Registers', 'FC23');

  final int code;
  final String name;
  final String shortName;

  const ModbusFunctionCode(this.code, this.name, this.shortName);

  bool get isReadFunction => code <= 0x04;
  bool get isWriteFunction => code >= 0x05;
  bool get isMultipleWrite => code == 0x0F || code == 0x10 || code == 0x17;
}

/// Data format for register interpretation
enum DataFormat {
  int16('INT16', 1),
  uint16('UINT16', 1),
  int32('INT32', 2),
  uint32('UINT32', 2),
  float32('FLOAT32', 2),
  float64('FLOAT64', 4),
  hex('HEX', 1),
  binary('BINARY', 1),
  ascii('ASCII', 1);

  final String displayName;
  final int registerCount;

  const DataFormat(this.displayName, this.registerCount);
}

/// Byte order for multi-register values
enum ByteOrder {
  bigEndian('Big Endian (AB CD)', 'ABCD'),
  littleEndian('Little Endian (CD AB)', 'CDAB'),
  bigEndianSwap('Big Endian Swap (BA DC)', 'BADC'),
  littleEndianSwap('Little Endian Swap (DC BA)', 'DCBA');

  final String displayName;
  final String shortName;

  const ByteOrder(this.displayName, this.shortName);
}

/// USB Serial chip types
enum UsbChipType {
  ch340('CH340', 0x1A86, [0x7523, 0x5523]),
  cp210x('CP210x', 0x10C4, [0xEA60, 0xEA70]),
  ftdi('FTDI', 0x0403, [0x6001, 0x6010, 0x6011, 0x6014, 0x6015]),
  pl2303('PL2303', 0x067B, [0x2303, 0x23A3]);

  final String name;
  final int vendorId;
  final List<int> productIds;

  const UsbChipType(this.name, this.vendorId, this.productIds);
}

/// Baud rate options
class BaudRates {
  static const List<int> all = [
    300, 600, 1200, 2400, 4800, 9600, 14400, 19200,
    28800, 38400, 57600, 115200, 230400, 460800, 921600
  ];
  static const int defaultRate = 9600;
}

/// Parity options
enum Parity {
  none('None', 'N'),
  even('Even', 'E'),
  odd('Odd', 'O'),
  mark('Mark', 'M'),
  space('Space', 'S');

  final String displayName;
  final String shortName;

  const Parity(this.displayName, this.shortName);
}

/// Stop bits
enum StopBits {
  one(1, '1'),
  onePointFive(1.5, '1.5'),
  two(2, '2');

  final double value;
  final String displayName;

  const StopBits(this.value, this.displayName);
}

/// Data bits
enum DataBits {
  five(5),
  six(6),
  seven(7),
  eight(8);

  final int value;

  const DataBits(this.value);
}

/// Connection state
enum ModbusConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// RTU Connection settings
class RtuConnectionSettings extends Equatable {
  final String portName;
  final int baudRate;
  final DataBits dataBits;
  final Parity parity;
  final StopBits stopBits;
  final int responseTimeout; // ms
  final int interFrameDelay; // ms

  const RtuConnectionSettings({
    this.portName = '',
    this.baudRate = 9600,
    this.dataBits = DataBits.eight,
    this.parity = Parity.none,
    this.stopBits = StopBits.one,
    this.responseTimeout = 1000,
    this.interFrameDelay = 50,
  });

  String get settingsSummary =>
      '$baudRate-${dataBits.value}${parity.shortName}${stopBits.displayName}';

  RtuConnectionSettings copyWith({
    String? portName,
    int? baudRate,
    DataBits? dataBits,
    Parity? parity,
    StopBits? stopBits,
    int? responseTimeout,
    int? interFrameDelay,
  }) {
    return RtuConnectionSettings(
      portName: portName ?? this.portName,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      parity: parity ?? this.parity,
      stopBits: stopBits ?? this.stopBits,
      responseTimeout: responseTimeout ?? this.responseTimeout,
      interFrameDelay: interFrameDelay ?? this.interFrameDelay,
    );
  }

  Map<String, dynamic> toJson() => {
    'portName': portName,
    'baudRate': baudRate,
    'dataBits': dataBits.value,
    'parity': parity.name,
    'stopBits': stopBits.value,
    'responseTimeout': responseTimeout,
    'interFrameDelay': interFrameDelay,
  };

  factory RtuConnectionSettings.fromJson(Map<String, dynamic> json) {
    return RtuConnectionSettings(
      portName: json['portName'] ?? '',
      baudRate: json['baudRate'] ?? 9600,
      dataBits: DataBits.values.firstWhere(
        (d) => d.value == json['dataBits'],
        orElse: () => DataBits.eight,
      ),
      parity: Parity.values.firstWhere(
        (p) => p.name == json['parity'],
        orElse: () => Parity.none,
      ),
      stopBits: StopBits.values.firstWhere(
        (s) => s.value == json['stopBits'],
        orElse: () => StopBits.one,
      ),
      responseTimeout: json['responseTimeout'] ?? 1000,
      interFrameDelay: json['interFrameDelay'] ?? 50,
    );
  }

  @override
  List<Object?> get props => [
    portName, baudRate, dataBits, parity, stopBits,
    responseTimeout, interFrameDelay
  ];
}

/// TCP Connection settings
class TcpConnectionSettings extends Equatable {
  final String ipAddress;
  final int port;
  final int connectionTimeout; // ms
  final int responseTimeout; // ms
  final bool keepAlive;

  const TcpConnectionSettings({
    this.ipAddress = '192.168.1.1',
    this.port = 502,
    this.connectionTimeout = 5000,
    this.responseTimeout = 1000,
    this.keepAlive = true,
  });

  String get settingsSummary => '$ipAddress:$port';

  TcpConnectionSettings copyWith({
    String? ipAddress,
    int? port,
    int? connectionTimeout,
    int? responseTimeout,
    bool? keepAlive,
  }) {
    return TcpConnectionSettings(
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      responseTimeout: responseTimeout ?? this.responseTimeout,
      keepAlive: keepAlive ?? this.keepAlive,
    );
  }

  Map<String, dynamic> toJson() => {
    'ipAddress': ipAddress,
    'port': port,
    'connectionTimeout': connectionTimeout,
    'responseTimeout': responseTimeout,
    'keepAlive': keepAlive,
  };

  factory TcpConnectionSettings.fromJson(Map<String, dynamic> json) {
    return TcpConnectionSettings(
      ipAddress: json['ipAddress'] ?? '192.168.1.1',
      port: json['port'] ?? 502,
      connectionTimeout: json['connectionTimeout'] ?? 5000,
      responseTimeout: json['responseTimeout'] ?? 1000,
      keepAlive: json['keepAlive'] ?? true,
    );
  }

  @override
  List<Object?> get props => [
    ipAddress, port, connectionTimeout, responseTimeout, keepAlive
  ];
}

/// Modbus request
class ModbusRequest extends Equatable {
  final int slaveId;
  final ModbusFunctionCode functionCode;
  final int startAddress;
  final int quantity;
  final List<int>? writeValues;
  final DataFormat dataFormat;
  final ByteOrder byteOrder;

  const ModbusRequest({
    required this.slaveId,
    required this.functionCode,
    required this.startAddress,
    required this.quantity,
    this.writeValues,
    this.dataFormat = DataFormat.uint16,
    this.byteOrder = ByteOrder.bigEndian,
  });

  ModbusRequest copyWith({
    int? slaveId,
    ModbusFunctionCode? functionCode,
    int? startAddress,
    int? quantity,
    List<int>? writeValues,
    DataFormat? dataFormat,
    ByteOrder? byteOrder,
  }) {
    return ModbusRequest(
      slaveId: slaveId ?? this.slaveId,
      functionCode: functionCode ?? this.functionCode,
      startAddress: startAddress ?? this.startAddress,
      quantity: quantity ?? this.quantity,
      writeValues: writeValues ?? this.writeValues,
      dataFormat: dataFormat ?? this.dataFormat,
      byteOrder: byteOrder ?? this.byteOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'slaveId': slaveId,
    'functionCode': functionCode.code,
    'startAddress': startAddress,
    'quantity': quantity,
    'writeValues': writeValues,
    'dataFormat': dataFormat.name,
    'byteOrder': byteOrder.name,
  };

  factory ModbusRequest.fromJson(Map<String, dynamic> json) {
    return ModbusRequest(
      slaveId: json['slaveId'] ?? 1,
      functionCode: ModbusFunctionCode.values.firstWhere(
        (fc) => fc.code == json['functionCode'],
        orElse: () => ModbusFunctionCode.readHoldingRegisters,
      ),
      startAddress: json['startAddress'] ?? 0,
      quantity: json['quantity'] ?? 1,
      writeValues: json['writeValues'] != null
          ? List<int>.from(json['writeValues'])
          : null,
      dataFormat: DataFormat.values.firstWhere(
        (df) => df.name == json['dataFormat'],
        orElse: () => DataFormat.uint16,
      ),
      byteOrder: ByteOrder.values.firstWhere(
        (bo) => bo.name == json['byteOrder'],
        orElse: () => ByteOrder.bigEndian,
      ),
    );
  }

  @override
  List<Object?> get props => [
    slaveId, functionCode, startAddress, quantity,
    writeValues, dataFormat, byteOrder
  ];
}

/// Modbus response
class ModbusResponse extends Equatable {
  final bool success;
  final List<int>? rawData;
  final List<dynamic>? interpretedData;
  final String? errorMessage;
  final int? exceptionCode;
  final DateTime timestamp;
  final int responseTimeMs;

  const ModbusResponse({
    required this.success,
    this.rawData,
    this.interpretedData,
    this.errorMessage,
    this.exceptionCode,
    required this.timestamp,
    required this.responseTimeMs,
  });

  factory ModbusResponse.success({
    required List<int> rawData,
    List<dynamic>? interpretedData,
    required int responseTimeMs,
  }) {
    return ModbusResponse(
      success: true,
      rawData: rawData,
      interpretedData: interpretedData,
      timestamp: DateTime.now(),
      responseTimeMs: responseTimeMs,
    );
  }

  factory ModbusResponse.error({
    required String message,
    int? exceptionCode,
    required int responseTimeMs,
  }) {
    return ModbusResponse(
      success: false,
      errorMessage: message,
      exceptionCode: exceptionCode,
      timestamp: DateTime.now(),
      responseTimeMs: responseTimeMs,
    );
  }

  String get exceptionName {
    if (exceptionCode == null) return '';
    switch (exceptionCode) {
      case 0x01: return 'Illegal Function';
      case 0x02: return 'Illegal Data Address';
      case 0x03: return 'Illegal Data Value';
      case 0x04: return 'Slave Device Failure';
      case 0x05: return 'Acknowledge';
      case 0x06: return 'Slave Device Busy';
      case 0x08: return 'Memory Parity Error';
      case 0x0A: return 'Gateway Path Unavailable';
      case 0x0B: return 'Gateway Target Failed';
      default: return 'Unknown Exception (0x${exceptionCode!.toRadixString(16).toUpperCase()})';
    }
  }

  @override
  List<Object?> get props => [
    success, rawData, interpretedData, errorMessage,
    exceptionCode, timestamp, responseTimeMs
  ];
}

/// Communication log entry
class LogEntry extends Equatable {
  final String id;
  final DateTime timestamp;
  final LogType type;
  final String direction; // TX or RX
  final List<int>? rawBytes;
  final String? message;
  final ModbusRequest? request;
  final ModbusResponse? response;
  final bool isError;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.direction,
    this.rawBytes,
    this.message,
    this.request,
    this.response,
    this.isError = false,
  });

  String get hexDump {
    if (rawBytes == null || rawBytes!.isEmpty) return '';
    return rawBytes!.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}.'
           '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  List<Object?> get props => [
    id, timestamp, type, direction, rawBytes, message, request, response, isError
  ];
}

enum LogType { request, response, info, warning, error, connection }

/// Device profile for saving frequently used settings
class DeviceProfile extends Equatable {
  final String id;
  final String name;
  final String description;
  final ConnectionType connectionType;
  final RtuConnectionSettings? rtuSettings;
  final TcpConnectionSettings? tcpSettings;
  final List<ModbusRequest> savedRequests;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeviceProfile({
    required this.id,
    required this.name,
    this.description = '',
    required this.connectionType,
    this.rtuSettings,
    this.tcpSettings,
    this.savedRequests = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  DeviceProfile copyWith({
    String? id,
    String? name,
    String? description,
    ConnectionType? connectionType,
    RtuConnectionSettings? rtuSettings,
    TcpConnectionSettings? tcpSettings,
    List<ModbusRequest>? savedRequests,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeviceProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      connectionType: connectionType ?? this.connectionType,
      rtuSettings: rtuSettings ?? this.rtuSettings,
      tcpSettings: tcpSettings ?? this.tcpSettings,
      savedRequests: savedRequests ?? this.savedRequests,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'connectionType': connectionType.name,
    'rtuSettings': rtuSettings?.toJson(),
    'tcpSettings': tcpSettings?.toJson(),
    'savedRequests': savedRequests.map((r) => r.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DeviceProfile.fromJson(Map<String, dynamic> json) {
    return DeviceProfile(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      connectionType: ConnectionType.values.firstWhere(
        (ct) => ct.name == json['connectionType'],
        orElse: () => ConnectionType.tcp,
      ),
      rtuSettings: json['rtuSettings'] != null
          ? RtuConnectionSettings.fromJson(json['rtuSettings'])
          : null,
      tcpSettings: json['tcpSettings'] != null
          ? TcpConnectionSettings.fromJson(json['tcpSettings'])
          : null,
      savedRequests: (json['savedRequests'] as List?)
          ?.map((r) => ModbusRequest.fromJson(r))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
    id, name, description, connectionType, rtuSettings,
    tcpSettings, savedRequests, createdAt, updatedAt
  ];
}

/// Polling configuration
class PollingConfig extends Equatable {
  final bool enabled;
  final int intervalMs;
  final ModbusRequest request;

  const PollingConfig({
    this.enabled = false,
    this.intervalMs = 1000,
    required this.request,
  });

  PollingConfig copyWith({
    bool? enabled,
    int? intervalMs,
    ModbusRequest? request,
  }) {
    return PollingConfig(
      enabled: enabled ?? this.enabled,
      intervalMs: intervalMs ?? this.intervalMs,
      request: request ?? this.request,
    );
  }

  @override
  List<Object?> get props => [enabled, intervalMs, request];
}
