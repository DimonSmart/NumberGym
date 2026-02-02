import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'app_log_buffer.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  LogEntry({
    required this.time,
    required this.level,
    required this.category,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime time;
  final LogLevel level;
  final String category;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final levelLabel = level.name.toUpperCase();
    final base = '[${time.toIso8601String()}] $levelLabel [$category] $message';
    if (error == null && stackTrace == null) {
      return base;
    }
    final buffer = StringBuffer(base);
    if (error != null) {
      buffer.write('\nerror: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nstack: $stackTrace');
    }
    return buffer.toString();
  }
}

class AppLogger {
  AppLogger._({int maxEntries = 500}) : _maxEntries = maxEntries;

  static final AppLogger instance = AppLogger._();

  final int _maxEntries;
  final List<LogEntry> _buffer = <LogEntry>[];
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get stream => _controller.stream;

  List<LogEntry> snapshot() => List<LogEntry>.unmodifiable(_buffer);

  bool _debugEnabled = kDebugMode;

  void setDebugEnabled(bool enabled) {
    _debugEnabled = enabled;
  }

  void log(
    LogLevel level,
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool toConsole = true,
  }) {
    if (level == LogLevel.debug && !_debugEnabled) {
      return;
    }

    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      category: category,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _buffer.add(entry);
    if (_buffer.length > _maxEntries) {
      _buffer.removeRange(0, _buffer.length - _maxEntries);
    }
    _controller.add(entry);

    AppLogBuffer.instance.add(entry.toString());

    if (toConsole) {
      dev.log(
        entry.message,
        name: 'app.$category',
        level: _toDevLevel(level),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  int _toDevLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

void appLogD(String category, String message) {
  AppLogger.instance.log(LogLevel.debug, category, message);
}

void appLogI(String category, String message) {
  AppLogger.instance.log(LogLevel.info, category, message);
}

void appLogW(
  String category,
  String message, {
  Object? error,
  StackTrace? st,
}) {
  AppLogger.instance
      .log(LogLevel.warn, category, message, error: error, stackTrace: st);
}

void appLogE(
  String category,
  String message, {
  Object? error,
  StackTrace? st,
}) {
  AppLogger.instance
      .log(LogLevel.error, category, message, error: error, stackTrace: st);
}
