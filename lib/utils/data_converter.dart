import 'dart:typed_data';
import '../models/modbus_models.dart';

/// Data format converter for Modbus register values
class DataConverter {
  /// Convert raw register values to interpreted data
  static List<dynamic> convertRegisters(
    List<int> registers,
    DataFormat format,
    ByteOrder byteOrder,
  ) {
    final results = <dynamic>[];

    switch (format) {
      case DataFormat.int16:
        for (final reg in registers) {
          results.add(_toInt16(reg));
        }
        break;

      case DataFormat.uint16:
        results.addAll(registers);
        break;

      case DataFormat.int32:
        for (int i = 0; i < registers.length - 1; i += 2) {
          results.add(_toInt32(registers[i], registers[i + 1], byteOrder));
        }
        break;

      case DataFormat.uint32:
        for (int i = 0; i < registers.length - 1; i += 2) {
          results.add(_toUint32(registers[i], registers[i + 1], byteOrder));
        }
        break;

      case DataFormat.float32:
        for (int i = 0; i < registers.length - 1; i += 2) {
          results.add(_toFloat32(registers[i], registers[i + 1], byteOrder));
        }
        break;

      case DataFormat.float64:
        for (int i = 0; i < registers.length - 3; i += 4) {
          results.add(_toFloat64(
            registers[i], registers[i + 1],
            registers[i + 2], registers[i + 3],
            byteOrder,
          ));
        }
        break;

      case DataFormat.hex:
        for (final reg in registers) {
          results.add('0x${reg.toRadixString(16).toUpperCase().padLeft(4, '0')}');
        }
        break;

      case DataFormat.binary:
        for (final reg in registers) {
          results.add(reg.toRadixString(2).padLeft(16, '0'));
        }
        break;

      case DataFormat.ascii:
        final chars = <int>[];
        for (final reg in registers) {
          chars.add((reg >> 8) & 0xFF);
          chars.add(reg & 0xFF);
        }
        results.add(String.fromCharCodes(
          chars.where((c) => c >= 32 && c <= 126),
        ));
        break;
    }

    return results;
  }

  /// Convert INT16 (signed 16-bit)
  static int _toInt16(int value) {
    if (value > 32767) {
      return value - 65536;
    }
    return value;
  }

  /// Convert to INT32 (signed 32-bit)
  static int _toInt32(int reg1, int reg2, ByteOrder byteOrder) {
    final bytes = _orderBytes32(reg1, reg2, byteOrder);
    final bd = ByteData(4);
    bd.setUint8(0, bytes[0]);
    bd.setUint8(1, bytes[1]);
    bd.setUint8(2, bytes[2]);
    bd.setUint8(3, bytes[3]);
    return bd.getInt32(0, Endian.big);
  }

  /// Convert to UINT32 (unsigned 32-bit)
  static int _toUint32(int reg1, int reg2, ByteOrder byteOrder) {
    final bytes = _orderBytes32(reg1, reg2, byteOrder);
    final bd = ByteData(4);
    bd.setUint8(0, bytes[0]);
    bd.setUint8(1, bytes[1]);
    bd.setUint8(2, bytes[2]);
    bd.setUint8(3, bytes[3]);
    return bd.getUint32(0, Endian.big);
  }

  /// Convert to FLOAT32 (IEEE 754)
  static double _toFloat32(int reg1, int reg2, ByteOrder byteOrder) {
    final bytes = _orderBytes32(reg1, reg2, byteOrder);
    final bd = ByteData(4);
    bd.setUint8(0, bytes[0]);
    bd.setUint8(1, bytes[1]);
    bd.setUint8(2, bytes[2]);
    bd.setUint8(3, bytes[3]);
    return bd.getFloat32(0, Endian.big);
  }

  /// Convert to FLOAT64 (IEEE 754 double)
  static double _toFloat64(
    int reg1, int reg2, int reg3, int reg4,
    ByteOrder byteOrder,
  ) {
    final bytes = _orderBytes64(reg1, reg2, reg3, reg4, byteOrder);
    final bd = ByteData(8);
    for (int i = 0; i < 8; i++) {
      bd.setUint8(i, bytes[i]);
    }
    return bd.getFloat64(0, Endian.big);
  }

  /// Order bytes for 32-bit values based on byte order
  static List<int> _orderBytes32(int reg1, int reg2, ByteOrder byteOrder) {
    final b1 = (reg1 >> 8) & 0xFF; // A
    final b2 = reg1 & 0xFF;        // B
    final b3 = (reg2 >> 8) & 0xFF; // C
    final b4 = reg2 & 0xFF;        // D

    switch (byteOrder) {
      case ByteOrder.bigEndian:      // ABCD
        return [b1, b2, b3, b4];
      case ByteOrder.littleEndian:   // CDAB
        return [b3, b4, b1, b2];
      case ByteOrder.bigEndianSwap:  // BADC
        return [b2, b1, b4, b3];
      case ByteOrder.littleEndianSwap: // DCBA
        return [b4, b3, b2, b1];
    }
  }

  /// Order bytes for 64-bit values
  static List<int> _orderBytes64(
    int reg1, int reg2, int reg3, int reg4,
    ByteOrder byteOrder,
  ) {
    final bytes32_1 = _orderBytes32(reg1, reg2, byteOrder);
    final bytes32_2 = _orderBytes32(reg3, reg4, byteOrder);

    switch (byteOrder) {
      case ByteOrder.bigEndian:
      case ByteOrder.bigEndianSwap:
        return [...bytes32_1, ...bytes32_2];
      case ByteOrder.littleEndian:
      case ByteOrder.littleEndianSwap:
        return [...bytes32_2, ...bytes32_1];
    }
  }

  /// Convert value to register(s) for writing
  static List<int> valueToRegisters(
    dynamic value,
    DataFormat format,
    ByteOrder byteOrder,
  ) {
    switch (format) {
      case DataFormat.int16:
        int intVal = value as int;
        if (intVal < 0) intVal += 65536;
        return [intVal & 0xFFFF];

      case DataFormat.uint16:
        return [(value as int) & 0xFFFF];

      case DataFormat.int32:
      case DataFormat.uint32:
        return _int32ToRegisters(value as int, byteOrder);

      case DataFormat.float32:
        return _float32ToRegisters(value as double, byteOrder);

      case DataFormat.float64:
        return _float64ToRegisters(value as double, byteOrder);

      case DataFormat.hex:
        if (value is String) {
          final hex = value.replaceAll('0x', '').replaceAll(' ', '');
          return [int.parse(hex, radix: 16) & 0xFFFF];
        }
        return [(value as int) & 0xFFFF];

      default:
        return [(value as int) & 0xFFFF];
    }
  }

  static List<int> _int32ToRegisters(int value, ByteOrder byteOrder) {
    final bd = ByteData(4);
    bd.setInt32(0, value, Endian.big);
    final bytes = [
      bd.getUint8(0),
      bd.getUint8(1),
      bd.getUint8(2),
      bd.getUint8(3),
    ];

    switch (byteOrder) {
      case ByteOrder.bigEndian:
        return [(bytes[0] << 8) | bytes[1], (bytes[2] << 8) | bytes[3]];
      case ByteOrder.littleEndian:
        return [(bytes[2] << 8) | bytes[3], (bytes[0] << 8) | bytes[1]];
      case ByteOrder.bigEndianSwap:
        return [(bytes[1] << 8) | bytes[0], (bytes[3] << 8) | bytes[2]];
      case ByteOrder.littleEndianSwap:
        return [(bytes[3] << 8) | bytes[2], (bytes[1] << 8) | bytes[0]];
    }
  }

  static List<int> _float32ToRegisters(double value, ByteOrder byteOrder) {
    final bd = ByteData(4);
    bd.setFloat32(0, value, Endian.big);
    final bytes = [
      bd.getUint8(0),
      bd.getUint8(1),
      bd.getUint8(2),
      bd.getUint8(3),
    ];

    switch (byteOrder) {
      case ByteOrder.bigEndian:
        return [(bytes[0] << 8) | bytes[1], (bytes[2] << 8) | bytes[3]];
      case ByteOrder.littleEndian:
        return [(bytes[2] << 8) | bytes[3], (bytes[0] << 8) | bytes[1]];
      case ByteOrder.bigEndianSwap:
        return [(bytes[1] << 8) | bytes[0], (bytes[3] << 8) | bytes[2]];
      case ByteOrder.littleEndianSwap:
        return [(bytes[3] << 8) | bytes[2], (bytes[1] << 8) | bytes[0]];
    }
  }

  static List<int> _float64ToRegisters(double value, ByteOrder byteOrder) {
    final bd = ByteData(8);
    bd.setFloat64(0, value, Endian.big);
    final bytes = List.generate(8, (i) => bd.getUint8(i));

    switch (byteOrder) {
      case ByteOrder.bigEndian:
        return [
          (bytes[0] << 8) | bytes[1],
          (bytes[2] << 8) | bytes[3],
          (bytes[4] << 8) | bytes[5],
          (bytes[6] << 8) | bytes[7],
        ];
      case ByteOrder.littleEndian:
        return [
          (bytes[6] << 8) | bytes[7],
          (bytes[4] << 8) | bytes[5],
          (bytes[2] << 8) | bytes[3],
          (bytes[0] << 8) | bytes[1],
        ];
      default:
        return [
          (bytes[0] << 8) | bytes[1],
          (bytes[2] << 8) | bytes[3],
          (bytes[4] << 8) | bytes[5],
          (bytes[6] << 8) | bytes[7],
        ];
    }
  }

  /// Format a value for display
  static String formatValue(dynamic value, DataFormat format, {int precision = 4}) {
    if (value == null) return '-';

    switch (format) {
      case DataFormat.float32:
      case DataFormat.float64:
        if (value is double) {
          if (value.isNaN || value.isInfinite) return value.toString();
          return value.toStringAsFixed(precision);
        }
        return value.toString();

      case DataFormat.hex:
        if (value is int) {
          return '0x${value.toRadixString(16).toUpperCase().padLeft(4, '0')}';
        }
        return value.toString();

      case DataFormat.binary:
        if (value is int) {
          return value.toRadixString(2).padLeft(16, '0');
        }
        return value.toString();

      default:
        return value.toString();
    }
  }

  /// Convert bytes to hex string
  static String bytesToHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  /// Parse hex string to bytes
  static List<int> hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '').replaceAll('0x', '');
    final bytes = <int>[];
    for (int i = 0; i < hex.length - 1; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
