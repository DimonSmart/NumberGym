import 'dart:collection';
import 'dart:convert';

class AppLogBuffer {
  AppLogBuffer._({int maxBytes = 100 * 1024}) : _maxBytes = maxBytes;

  static final AppLogBuffer instance = AppLogBuffer._();

  final int _maxBytes;
  final Queue<_LogEntry> _entries = Queue<_LogEntry>();
  int _byteLength = 0;

  int get byteLength => _byteLength;
  bool get isEmpty => _entries.isEmpty;

  String get text => _entries.map((entry) => entry.text).join();

  void add(String message) {
    final normalized = message.replaceAll('\r', '');
    final line = normalized.endsWith('\n') ? normalized : '$normalized\n';
    final bytes = utf8.encode(line).length;
    if (bytes >= _maxBytes) {
      _entries.clear();
      _byteLength = 0;
      final clipped = _clipToMaxBytes(line);
      _appendEntry(clipped);
      return;
    }
    _appendEntry(line);
    _trimToLimit();
  }

  void _appendEntry(String line) {
    final bytes = utf8.encode(line).length;
    _entries.add(_LogEntry(line, bytes));
    _byteLength += bytes;
  }

  void _trimToLimit() {
    while (_byteLength > _maxBytes && _entries.isNotEmpty) {
      final removed = _entries.removeFirst();
      _byteLength -= removed.bytes;
    }
  }

  String _clipToMaxBytes(String line) {
    final bytes = utf8.encode(line);
    final start = bytes.length - _maxBytes;
    final sliced = bytes.sublist(start);
    return utf8.decode(sliced, allowMalformed: true);
  }
}

class _LogEntry {
  final String text;
  final int bytes;
  const _LogEntry(this.text, this.bytes);
}
