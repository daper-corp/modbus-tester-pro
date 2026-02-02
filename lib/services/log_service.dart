import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/modbus_models.dart';
import '../utils/data_converter.dart';

/// Service for managing communication logs
class LogService {
  final List<LogEntry> _logs = [];
  final _logController = StreamController<List<LogEntry>>.broadcast();
  final int maxLogs;
  final _uuid = const Uuid();

  LogService({this.maxLogs = 1000});

  List<LogEntry> get logs => List.unmodifiable(_logs);
  Stream<List<LogEntry>> get logStream => _logController.stream;

  /// Add a log entry
  void addLog(LogEntry entry) {
    _logs.insert(0, entry);
    if (_logs.length > maxLogs) {
      _logs.removeLast();
    }
    _logController.add(_logs);
  }

  /// Log a request
  void logRequest(ModbusRequest request, List<int>? rawBytes) {
    addLog(LogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: LogType.request,
      direction: 'TX',
      rawBytes: rawBytes,
      request: request,
      message: _formatRequestMessage(request),
    ));
  }

  /// Log a response
  void logResponse(ModbusResponse response, ModbusRequest? request) {
    addLog(LogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: LogType.response,
      direction: 'RX',
      rawBytes: response.rawData,
      response: response,
      request: request,
      message: _formatResponseMessage(response),
      isError: !response.success,
    ));
  }

  /// Log info message
  void logInfo(String message) {
    addLog(LogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: LogType.info,
      direction: '--',
      message: message,
    ));
  }

  /// Log warning message
  void logWarning(String message) {
    addLog(LogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: LogType.warning,
      direction: '--',
      message: message,
    ));
  }

  /// Log error message
  void logError(String message) {
    addLog(LogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: LogType.error,
      direction: '--',
      message: message,
      isError: true,
    ));
  }

  /// Log connection event
  void logConnection(String message, {bool isError = false}) {
    addLog(LogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: LogType.connection,
      direction: '--',
      message: message,
      isError: isError,
    ));
  }

  String _formatRequestMessage(ModbusRequest request) {
    return 'Slave ${request.slaveId} | ${request.functionCode.shortName} | '
           'Addr: ${request.startAddress} | Qty: ${request.quantity}';
  }

  String _formatResponseMessage(ModbusResponse response) {
    if (!response.success) {
      if (response.exceptionCode != null) {
        return 'Error: ${response.exceptionName}';
      }
      return 'Error: ${response.errorMessage}';
    }
    return 'OK (${response.responseTimeMs}ms) | '
           '${response.rawData?.length ?? 0} values';
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    _logController.add(_logs);
  }

  /// Export logs to CSV format
  String exportToCsv() {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Timestamp,Direction,Type,Message,HEX Data,Response Time (ms),Error');
    
    for (final log in _logs.reversed) {
      final hexData = log.rawBytes != null
          ? DataConverter.bytesToHex(log.rawBytes!)
          : '';
      final responseTime = log.response?.responseTimeMs.toString() ?? '';
      final escapedMessage = _escapeCsv(log.message ?? '');
      
      buffer.writeln(
        '${log.timestamp.toIso8601String()},'
        '${log.direction},'
        '${log.type.name},'
        '$escapedMessage,'
        '$hexData,'
        '$responseTime,'
        '${log.isError}'
      );
    }
    
    return buffer.toString();
  }

  /// Export logs to text format
  String exportToText() {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════════════════════════════');
    buffer.writeln('                    MODBUS COMMUNICATION LOG                    ');
    buffer.writeln('═══════════════════════════════════════════════════════════════');
    buffer.writeln('Export Date: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Entries: ${_logs.length}');
    buffer.writeln('───────────────────────────────────────────────────────────────');
    buffer.writeln();
    
    for (final log in _logs.reversed) {
      buffer.writeln('[${log.formattedTimestamp}] ${log.direction} | ${log.type.name.toUpperCase()}');
      if (log.message != null) {
        buffer.writeln('  Message: ${log.message}');
      }
      if (log.rawBytes != null && log.rawBytes!.isNotEmpty) {
        buffer.writeln('  HEX: ${log.hexDump}');
      }
      if (log.request != null) {
        buffer.writeln('  Request: Slave=${log.request!.slaveId} '
                      'FC=${log.request!.functionCode.shortName} '
                      'Addr=${log.request!.startAddress} '
                      'Qty=${log.request!.quantity}');
      }
      if (log.response != null) {
        buffer.writeln('  Response Time: ${log.response!.responseTimeMs}ms');
        if (log.response!.interpretedData != null) {
          buffer.writeln('  Data: ${log.response!.interpretedData!.join(', ')}');
        }
      }
      buffer.writeln();
    }
    
    buffer.writeln('═══════════════════════════════════════════════════════════════');
    buffer.writeln('                         END OF LOG                            ');
    buffer.writeln('═══════════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }

  /// Export logs to JSON format
  String exportToJson() {
    final logMaps = _logs.reversed.map((log) => {
      'timestamp': log.timestamp.toIso8601String(),
      'direction': log.direction,
      'type': log.type.name,
      'message': log.message,
      'hexData': log.rawBytes != null ? DataConverter.bytesToHex(log.rawBytes!) : null,
      'isError': log.isError,
      if (log.request != null) 'request': {
        'slaveId': log.request!.slaveId,
        'functionCode': log.request!.functionCode.code,
        'startAddress': log.request!.startAddress,
        'quantity': log.request!.quantity,
      },
      if (log.response != null) 'response': {
        'success': log.response!.success,
        'responseTimeMs': log.response!.responseTimeMs,
        'errorMessage': log.response!.errorMessage,
        'exceptionCode': log.response!.exceptionCode,
        'data': log.response!.interpretedData,
      },
    }).toList();

    return const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'totalEntries': _logs.length,
      'logs': logMaps,
    });
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void dispose() {
    _logController.close();
  }
}
