import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class TtsVoice {
  const TtsVoice({
    required this.id,
    required this.name,
    required this.locale,
  });

  final String id;
  final String name;
  final String locale;

  String get label {
    final resolvedName = name.isEmpty ? id : name;
    if (locale.isEmpty) {
      return resolvedName;
    }
    return '$resolvedName ($locale)';
  }
}

abstract class TtsServiceBase {
  Future<bool> isLanguageAvailable(String locale);
  Future<List<TtsVoice>> listVoices();
  Future<void> setVoice(TtsVoice voice);
  Future<void> speak(String text);
  void dispose();
}

class TtsService implements TtsServiceBase {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _disposed = false;

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    final result = await _tts.isLanguageAvailable(locale);
    if (result is bool) {
      return result;
    }
    if (result == null) {
      return false;
    }
    return result.toString().toLowerCase() == 'true';
  }

  @override
  Future<List<TtsVoice>> listVoices() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return const [];
    final voices = <TtsVoice>[];
    for (final entry in raw) {
      if (entry is Map) {
        final parsed = _parseVoice(entry);
        if (parsed != null) {
          voices.add(parsed);
        }
      }
    }
    return voices;
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    if (voice.locale.trim().isNotEmpty) {
      await _tts.setLanguage(voice.locale);
    }
    final payload = <String, String>{};
    if (voice.name.trim().isNotEmpty) {
      payload['name'] = voice.name;
    }
    if (voice.locale.trim().isNotEmpty) {
      payload['locale'] = voice.locale;
    }
    if (payload.isEmpty) return;
    await _tts.setVoice(payload);
  }

  @override
  Future<void> speak(String text) async {
    if (_disposed) return;
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_tts.stop());
  }
}

List<TtsVoice> filterVoicesByLocale(List<TtsVoice> voices, String locale) {
  if (locale.trim().isEmpty) return voices;
  final normalizedTarget = _normalizeLocale(locale);
  final prefix = normalizedTarget.split('-').first;
  final exact = <TtsVoice>[];
  final partial = <TtsVoice>[];
  for (final voice in voices) {
    if (voice.locale.trim().isEmpty) continue;
    final normalized = _normalizeLocale(voice.locale);
    if (normalized == normalizedTarget) {
      exact.add(voice);
    } else if (normalized.startsWith(prefix)) {
      partial.add(voice);
    }
  }
  if (exact.isNotEmpty) return exact;
  if (partial.isNotEmpty) return partial;
  return voices;
}

String _normalizeLocale(String locale) {
  return locale.toLowerCase().replaceAll('_', '-');
}

TtsVoice? _parseVoice(Map<dynamic, dynamic> voice) {
  final name = _stringValue(voice['name']);
  final locale = _stringValue(voice['locale']);
  final identifier = _stringValue(voice['identifier']);
  final id = identifier ?? name ?? _stringValue(voice['id']);
  final resolvedId = id?.trim();
  if (resolvedId == null || resolvedId.isEmpty) {
    return null;
  }
  final resolvedName =
      (name?.trim().isNotEmpty ?? false) ? name!.trim() : resolvedId;
  return TtsVoice(
    id: resolvedId,
    name: resolvedName,
    locale: locale?.trim() ?? '',
  );
}

String? _stringValue(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}
