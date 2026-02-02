import 'package:equatable/equatable.dart';
import 'modbus_models.dart';

/// Register definition with metadata
class RegisterDefinition extends Equatable {
  final String id;
  final String name;
  final String description;
  final int address;
  final ModbusFunctionCode functionCode;
  final DataFormat dataFormat;
  final ByteOrder byteOrder;
  final double? scaleFactor;
  final double? offset;
  final String? unit;
  final double? minValue;
  final double? maxValue;
  final int registerCount;
  final bool isWatchlisted;
  final Map<int, String>? enumMapping; // For status registers

  const RegisterDefinition({
    required this.id,
    required this.name,
    this.description = '',
    required this.address,
    this.functionCode = ModbusFunctionCode.readHoldingRegisters,
    this.dataFormat = DataFormat.uint16,
    this.byteOrder = ByteOrder.bigEndian,
    this.scaleFactor,
    this.offset,
    this.unit,
    this.minValue,
    this.maxValue,
    this.registerCount = 1,
    this.isWatchlisted = false,
    this.enumMapping,
  });

  RegisterDefinition copyWith({
    String? id,
    String? name,
    String? description,
    int? address,
    ModbusFunctionCode? functionCode,
    DataFormat? dataFormat,
    ByteOrder? byteOrder,
    double? scaleFactor,
    double? offset,
    String? unit,
    double? minValue,
    double? maxValue,
    int? registerCount,
    bool? isWatchlisted,
    Map<int, String>? enumMapping,
  }) {
    return RegisterDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      functionCode: functionCode ?? this.functionCode,
      dataFormat: dataFormat ?? this.dataFormat,
      byteOrder: byteOrder ?? this.byteOrder,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      offset: offset ?? this.offset,
      unit: unit ?? this.unit,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      registerCount: registerCount ?? this.registerCount,
      isWatchlisted: isWatchlisted ?? this.isWatchlisted,
      enumMapping: enumMapping ?? this.enumMapping,
    );
  }

  /// Apply scaling to raw value
  dynamic applyScaling(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is! num) return rawValue;
    
    double value = rawValue.toDouble();
    if (scaleFactor != null) value *= scaleFactor!;
    if (offset != null) value += offset!;
    return value;
  }

  /// Format value with unit
  String formatValue(dynamic value) {
    if (value == null) return '-';
    
    // Check enum mapping
    if (enumMapping != null && value is int && enumMapping!.containsKey(value)) {
      return enumMapping![value]!;
    }
    
    final scaled = applyScaling(value);
    String result;
    
    if (scaled is double) {
      if (scaled.abs() >= 1000000) {
        result = '${(scaled / 1000000).toStringAsFixed(2)}M';
      } else if (scaled.abs() >= 1000) {
        result = '${(scaled / 1000).toStringAsFixed(2)}k';
      } else {
        result = scaled.toStringAsFixed(dataFormat == DataFormat.float32 || dataFormat == DataFormat.float64 ? 3 : 1);
      }
    } else {
      result = scaled.toString();
    }
    
    if (unit != null && unit!.isNotEmpty) {
      result += ' $unit';
    }
    
    return result;
  }

  /// Check if value is in valid range
  bool isValueValid(dynamic value) {
    if (value == null) return false;
    if (value is! num) return true;
    
    final scaled = applyScaling(value);
    if (scaled is! num) return true;
    
    if (minValue != null && scaled < minValue!) return false;
    if (maxValue != null && scaled > maxValue!) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'address': address,
    'functionCode': functionCode.code,
    'dataFormat': dataFormat.name,
    'byteOrder': byteOrder.name,
    'scaleFactor': scaleFactor,
    'offset': offset,
    'unit': unit,
    'minValue': minValue,
    'maxValue': maxValue,
    'registerCount': registerCount,
    'isWatchlisted': isWatchlisted,
    'enumMapping': enumMapping?.map((k, v) => MapEntry(k.toString(), v)),
  };

  factory RegisterDefinition.fromJson(Map<String, dynamic> json) {
    return RegisterDefinition(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'Unknown',
      description: json['description'] ?? '',
      address: json['address'] ?? 0,
      functionCode: ModbusFunctionCode.values.firstWhere(
        (fc) => fc.code == json['functionCode'],
        orElse: () => ModbusFunctionCode.readHoldingRegisters,
      ),
      dataFormat: DataFormat.values.firstWhere(
        (df) => df.name == json['dataFormat'],
        orElse: () => DataFormat.uint16,
      ),
      byteOrder: ByteOrder.values.firstWhere(
        (bo) => bo.name == json['byteOrder'],
        orElse: () => ByteOrder.bigEndian,
      ),
      scaleFactor: json['scaleFactor']?.toDouble(),
      offset: json['offset']?.toDouble(),
      unit: json['unit'],
      minValue: json['minValue']?.toDouble(),
      maxValue: json['maxValue']?.toDouble(),
      registerCount: json['registerCount'] ?? 1,
      isWatchlisted: json['isWatchlisted'] ?? false,
      enumMapping: json['enumMapping'] != null
          ? Map<int, String>.from(
              (json['enumMapping'] as Map).map((k, v) => MapEntry(int.parse(k.toString()), v.toString())),
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id, name, description, address, functionCode, dataFormat, byteOrder,
    scaleFactor, offset, unit, minValue, maxValue, registerCount, isWatchlisted,
  ];
}

/// Register value with history
class RegisterValue extends Equatable {
  final RegisterDefinition definition;
  final dynamic currentValue;
  final dynamic previousValue;
  final DateTime timestamp;
  final List<RegisterHistoryEntry> history;
  final bool hasError;
  final String? errorMessage;
  final int quality; // 0-100, quality indicator

  const RegisterValue({
    required this.definition,
    this.currentValue,
    this.previousValue,
    required this.timestamp,
    this.history = const [],
    this.hasError = false,
    this.errorMessage,
    this.quality = 100,
  });

  RegisterValue copyWith({
    RegisterDefinition? definition,
    dynamic currentValue,
    dynamic previousValue,
    DateTime? timestamp,
    List<RegisterHistoryEntry>? history,
    bool? hasError,
    String? errorMessage,
    int? quality,
  }) {
    return RegisterValue(
      definition: definition ?? this.definition,
      currentValue: currentValue ?? this.currentValue,
      previousValue: previousValue ?? this.previousValue,
      timestamp: timestamp ?? this.timestamp,
      history: history ?? this.history,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      quality: quality ?? this.quality,
    );
  }

  /// Check if value changed
  bool get hasChanged => currentValue != previousValue;

  /// Get change direction
  int get changeDirection {
    if (currentValue == null || previousValue == null) return 0;
    if (currentValue is! num || previousValue is! num) return 0;
    if (currentValue > previousValue) return 1;
    if (currentValue < previousValue) return -1;
    return 0;
  }

  /// Get formatted value
  String get formattedValue => definition.formatValue(currentValue);

  /// Check if value is valid
  bool get isValid => !hasError && definition.isValueValid(currentValue);

  @override
  List<Object?> get props => [
    definition, currentValue, previousValue, timestamp, hasError, quality,
  ];
}

/// History entry for trending
class RegisterHistoryEntry extends Equatable {
  final DateTime timestamp;
  final dynamic value;
  final int quality;

  const RegisterHistoryEntry({
    required this.timestamp,
    required this.value,
    this.quality = 100,
  });

  @override
  List<Object?> get props => [timestamp, value, quality];
}

/// Watchlist group
class WatchlistGroup extends Equatable {
  final String id;
  final String name;
  final String description;
  final List<RegisterDefinition> registers;
  final int pollingIntervalMs;
  final bool isActive;
  final DateTime createdAt;

  const WatchlistGroup({
    required this.id,
    required this.name,
    this.description = '',
    this.registers = const [],
    this.pollingIntervalMs = 1000,
    this.isActive = false,
    required this.createdAt,
  });

  WatchlistGroup copyWith({
    String? id,
    String? name,
    String? description,
    List<RegisterDefinition>? registers,
    int? pollingIntervalMs,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return WatchlistGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      registers: registers ?? this.registers,
      pollingIntervalMs: pollingIntervalMs ?? this.pollingIntervalMs,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'registers': registers.map((r) => r.toJson()).toList(),
    'pollingIntervalMs': pollingIntervalMs,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WatchlistGroup.fromJson(Map<String, dynamic> json) {
    return WatchlistGroup(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      registers: (json['registers'] as List?)
          ?.map((r) => RegisterDefinition.fromJson(r))
          .toList() ?? [],
      pollingIntervalMs: json['pollingIntervalMs'] ?? 1000,
      isActive: json['isActive'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  @override
  List<Object?> get props => [
    id, name, description, registers, pollingIntervalMs, isActive, createdAt,
  ];
}

// CommunicationStats has been moved to communication_stats.dart
// Use: import '../models/communication_stats.dart';
