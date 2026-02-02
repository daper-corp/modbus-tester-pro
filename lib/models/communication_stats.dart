import 'package:equatable/equatable.dart';
import 'dart:math' as math;

/// Communication statistics for monitoring Modbus performance
class CommunicationStats extends Equatable {
  final DateTime startTime;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int timeoutCount;
  final int crcErrorCount;
  final int exceptionCount;
  final List<int> responseTimes; // ms
  final int maxHistorySize;
  
  const CommunicationStats({
    required this.startTime,
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.timeoutCount = 0,
    this.crcErrorCount = 0,
    this.exceptionCount = 0,
    this.responseTimes = const [],
    this.maxHistorySize = 1000,
  });
  
  /// Record a new request result
  CommunicationStats recordRequest(
    bool success,
    int responseTimeMs, {
    bool isTimeout = false,
    bool isCrcError = false,
    bool isException = false,
  }) {
    final newResponseTimes = [...responseTimes, responseTimeMs];
    if (newResponseTimes.length > maxHistorySize) {
      newResponseTimes.removeAt(0);
    }
    
    return CommunicationStats(
      startTime: startTime,
      totalRequests: totalRequests + 1,
      successfulRequests: success ? successfulRequests + 1 : successfulRequests,
      failedRequests: success ? failedRequests : failedRequests + 1,
      timeoutCount: isTimeout ? timeoutCount + 1 : timeoutCount,
      crcErrorCount: isCrcError ? crcErrorCount + 1 : crcErrorCount,
      exceptionCount: isException ? exceptionCount + 1 : exceptionCount,
      responseTimes: newResponseTimes,
      maxHistorySize: maxHistorySize,
    );
  }
  
  /// Success rate (0-100%)
  double get successRate => totalRequests > 0 
      ? (successfulRequests / totalRequests) * 100 
      : 0.0;
  
  /// Average response time in milliseconds
  double get averageResponseTime => responseTimes.isNotEmpty
      ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
      : 0.0;
  
  /// Minimum response time
  int get minResponseTime => responseTimes.isNotEmpty
      ? responseTimes.reduce(math.min)
      : 0;
  
  /// Maximum response time
  int get maxResponseTime => responseTimes.isNotEmpty
      ? responseTimes.reduce(math.max)
      : 0;
  
  /// Standard deviation of response times
  double get responseTimeStdDev {
    if (responseTimes.length < 2) return 0.0;
    
    final mean = averageResponseTime;
    final variance = responseTimes
        .map((t) => math.pow(t - mean, 2))
        .reduce((a, b) => a + b) / responseTimes.length;
    
    return math.sqrt(variance);
  }
  
  /// Jitter (variation in response time)
  double get jitter {
    if (responseTimes.length < 2) return 0.0;
    
    double sumDiff = 0.0;
    for (int i = 1; i < responseTimes.length; i++) {
      sumDiff += (responseTimes[i] - responseTimes[i - 1]).abs();
    }
    
    return sumDiff / (responseTimes.length - 1);
  }
  
  /// Uptime duration
  Duration get uptime => DateTime.now().difference(startTime);
  
  /// Requests per minute
  double get requestsPerMinute {
    final minutes = uptime.inSeconds / 60;
    return minutes > 0 ? totalRequests / minutes : 0.0;
  }
  
  /// Reset statistics
  CommunicationStats reset() {
    return CommunicationStats(startTime: DateTime.now());
  }
  
  /// Get recent response time trend (last N samples)
  List<int> getRecentTrend([int samples = 60]) {
    if (responseTimes.length <= samples) return responseTimes;
    return responseTimes.sublist(responseTimes.length - samples);
  }
  
  /// Check if communication quality is good
  CommunicationQuality get quality {
    if (totalRequests < 10) return CommunicationQuality.unknown;
    
    if (successRate >= 99 && averageResponseTime < 100) {
      return CommunicationQuality.excellent;
    } else if (successRate >= 95 && averageResponseTime < 200) {
      return CommunicationQuality.good;
    } else if (successRate >= 90 && averageResponseTime < 500) {
      return CommunicationQuality.fair;
    } else {
      return CommunicationQuality.poor;
    }
  }
  
  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'failedRequests': failedRequests,
    'timeoutCount': timeoutCount,
    'crcErrorCount': crcErrorCount,
    'exceptionCount': exceptionCount,
    'successRate': successRate,
    'averageResponseTime': averageResponseTime,
    'minResponseTime': minResponseTime,
    'maxResponseTime': maxResponseTime,
    'jitter': jitter,
    'quality': quality.name,
  };
  
  @override
  List<Object?> get props => [
    startTime, totalRequests, successfulRequests, failedRequests,
    timeoutCount, crcErrorCount, exceptionCount, responseTimes,
  ];
}

enum CommunicationQuality {
  unknown('Unknown', '?'),
  excellent('Excellent', 'A+'),
  good('Good', 'A'),
  fair('Fair', 'B'),
  poor('Poor', 'C');
  
  final String displayName;
  final String grade;
  
  const CommunicationQuality(this.displayName, this.grade);
}

/// Alarm configuration for monitoring
class AlarmConfig extends Equatable {
  final bool enabled;
  final double minSuccessRate;
  final int maxResponseTime;
  final int maxConsecutiveFailures;
  final bool soundEnabled;
  final bool vibrationEnabled;
  
  const AlarmConfig({
    this.enabled = true,
    this.minSuccessRate = 95.0,
    this.maxResponseTime = 500,
    this.maxConsecutiveFailures = 3,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });
  
  AlarmConfig copyWith({
    bool? enabled,
    double? minSuccessRate,
    int? maxResponseTime,
    int? maxConsecutiveFailures,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return AlarmConfig(
      enabled: enabled ?? this.enabled,
      minSuccessRate: minSuccessRate ?? this.minSuccessRate,
      maxResponseTime: maxResponseTime ?? this.maxResponseTime,
      maxConsecutiveFailures: maxConsecutiveFailures ?? this.maxConsecutiveFailures,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
  
  @override
  List<Object?> get props => [
    enabled, minSuccessRate, maxResponseTime,
    maxConsecutiveFailures, soundEnabled, vibrationEnabled,
  ];
}

/// Active alarm
class Alarm extends Equatable {
  final String id;
  final AlarmType type;
  final String message;
  final DateTime timestamp;
  final bool acknowledged;
  final Map<String, dynamic>? metadata;
  
  const Alarm({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.acknowledged = false,
    this.metadata,
  });
  
  Alarm copyWith({
    bool? acknowledged,
  }) {
    return Alarm(
      id: id,
      type: type,
      message: message,
      timestamp: timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
      metadata: metadata,
    );
  }
  
  @override
  List<Object?> get props => [id, type, message, timestamp, acknowledged, metadata];
}

enum AlarmType {
  connectionLost('Connection Lost', AlarmSeverity.critical),
  communicationTimeout('Communication Timeout', AlarmSeverity.warning),
  lowSuccessRate('Low Success Rate', AlarmSeverity.warning),
  highResponseTime('High Response Time', AlarmSeverity.info),
  crcError('CRC Error', AlarmSeverity.warning),
  modbusException('Modbus Exception', AlarmSeverity.warning),
  valueOutOfRange('Value Out of Range', AlarmSeverity.info);
  
  final String displayName;
  final AlarmSeverity severity;
  
  const AlarmType(this.displayName, this.severity);
}

enum AlarmSeverity {
  info,
  warning,
  critical,
}
