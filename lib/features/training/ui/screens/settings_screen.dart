import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/learning_language.dart';
import '../../domain/services/internet_checker.dart';
import '../../domain/services/tts_service.dart';
import '../../domain/training_task.dart';
import 'package:number_gym/core/logging/app_log_buffer.dart';

class SettingsScreen extends StatefulWidget {
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  const SettingsScreen({
    super.key,
    required this.settingsBox,
    required this.progressBox,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  late final TtsServiceBase _ttsService;
  late LearningLanguage _language;
  late int _answerSeconds;
  late int _hintStreakCount;
  late bool _premiumPronunciation;
  bool _ttsAvailable = true;
  bool _ttsLoading = false;
  List<TtsVoice> _ttsVoices = const [];
  String? _ttsVoiceId;
  bool _ttsPreviewing = false;
  TrainingTaskKind? _debugForcedTaskKind;
  Timer? _internetTimer;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _ttsService = TtsService();
    _language = _settingsRepository.readLearningLanguage();
    _answerSeconds = _settingsRepository.readAnswerDurationSeconds();
    _hintStreakCount = _settingsRepository.readHintStreakCount();
    _premiumPronunciation =
      _settingsRepository.readPremiumPronunciationEnabled();
    _loadTtsData();
    _refreshInternetStatus();
    _internetTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshInternetStatus(),
    );
    if (kDebugMode) {
      _debugForcedTaskKind = _settingsRepository.readDebugForcedTaskKind();
    }
  }

  @override
  void dispose() {
    _internetTimer?.cancel();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This will clear progress for the selected language.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _progressRepository.reset(language: _language);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Progress reset for ${_language.label}.')),
    );
  }

  Future<void> _updateLanguage(LearningLanguage value) async {
    setState(() {
      _language = value;
    });
    await _settingsRepository.setLearningLanguage(value);
    await _loadTtsData();
  }

  Future<void> _updateAnswerSeconds(int seconds) async {
    setState(() {
      _answerSeconds = seconds;
    });
    await _settingsRepository.setAnswerDurationSeconds(seconds);
  }

  Future<void> _updateHintStreakCount(int count) async {
    setState(() {
      _hintStreakCount = count;
    });
    await _settingsRepository.setHintStreakCount(count);
  }

  Future<void> _updatePremiumPronunciation(bool enabled) async {
    setState(() {
      _premiumPronunciation = enabled;
    });
    await _settingsRepository.setPremiumPronunciationEnabled(enabled);
  }

  Future<void> _loadTtsData() async {
    if (!mounted) return;
    setState(() {
      _ttsLoading = true;
    });
    final locale = _language.locale;
    final available = await _ttsService.isLanguageAvailable(locale);
    final voices = await _ttsService.listVoices();
    final filtered = filterVoicesByLocale(voices, locale);
    String? selected = _settingsRepository.readTtsVoiceId(_language);
    if (selected != null &&
        filtered.every((voice) => voice.id != selected)) {
      selected = null;
    }
    if (selected == null && filtered.isNotEmpty) {
      selected = filtered.first.id;
      await _settingsRepository.setTtsVoiceId(_language, selected);
    }
    if (!mounted) return;
    setState(() {
      _ttsAvailable = available;
      _ttsVoices = filtered;
      _ttsVoiceId = selected;
      _ttsLoading = false;
    });
  }

  Future<void> _updateTtsVoiceId(String? voiceId) async {
    if (voiceId == null || voiceId.trim().isEmpty) return;
    setState(() {
      _ttsVoiceId = voiceId;
    });
    await _settingsRepository.setTtsVoiceId(_language, voiceId);
  }

  Future<void> _previewTtsVoice() async {
    if (_ttsLoading || _ttsPreviewing) return;
    if (!_ttsAvailable) {
      _showSnack('Text-to-speech is not available for this language.');
      return;
    }
    if (_ttsVoices.isEmpty) {
      _showSnack('No voices found to preview.');
      return;
    }
    final selectedId = _ttsVoiceId;
    final selectedVoice = selectedId == null
        ? _ttsVoices.first
        : _ttsVoices.firstWhere(
            (voice) => voice.id == selectedId,
            orElse: () => _ttsVoices.first,
          );
    setState(() {
      _ttsPreviewing = true;
    });
    try {
      await _ttsService.setVoice(selectedVoice);
      await _ttsService.speak(_ttsPreviewText(_language));
    } catch (error) {
      _showSnack('Preview failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _ttsPreviewing = false;
        });
      }
    }
  }

  String _ttsPreviewText(LearningLanguage language) {
    switch (language) {
      case LearningLanguage.spanish:
        return '¡Hola! Soy tu voz nueva. ¿Qué tal sueno?';
      case LearningLanguage.english:
        return 'Hi! I’m your new voice. How do I sound?';
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _refreshInternetStatus() async {
    final hasConnection = await hasInternet();
    if (!mounted || _hasInternet == hasConnection) return;
    setState(() {
      _hasInternet = hasConnection;
    });
  }

  Future<void> _updateDebugForcedTaskKind(TrainingTaskKind? kind) async {
    setState(() {
      _debugForcedTaskKind = kind;
    });
    await _settingsRepository.setDebugForcedTaskKind(kind);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logBuffer = AppLogBuffer.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Learning language',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LearningLanguage>(
            initialValue: _language,
            onChanged: (value) {
              if (value != null) {
                _updateLanguage(value);
              }
            },
            items: LearningLanguage.values
                .map(
                  (language) => DropdownMenuItem(
                    value: language,
                    child: Text(language.label),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Text-to-speech',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_ttsLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.record_voice_over,
                  size: 18,
                  color: _ttsAvailable
                      ? Colors.green.shade600
                      : theme.colorScheme.error,
                ),
              const SizedBox(width: 8),
              Text(
                _ttsLoading
                    ? 'TTS: Checking...'
                    : 'TTS: ${_ttsAvailable ? 'Available' : 'Unavailable'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _ttsAvailable
                      ? Colors.green.shade700
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!_ttsAvailable && !_ttsLoading) ...[
            const SizedBox(height: 6),
            Text(
              'Скачайте голос в настройках устройства.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_ttsLoading)
            const LinearProgressIndicator()
          else if (_ttsVoices.isEmpty)
            Text(
              'No voices found for ${_language.label}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _ttsVoiceId,
                    onChanged: _ttsAvailable ? _updateTtsVoiceId : null,
                    isExpanded: true,
                    items: _ttsVoices
                        .map(
                          (voice) => DropdownMenuItem(
                            value: voice.id,
                            child: Text(
                              voice.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => _ttsVoices
                        .map(
                          (voice) => Text(
                            voice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Voice',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed:
                      _ttsAvailable && !_ttsPreviewing ? _previewTtsVoice : null,
                  icon: _ttsPreviewing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        )
                      : const Icon(Icons.volume_up),
                  label: Text(_ttsPreviewing ? 'Playing' : 'Preview'),
                ),
              ],
            ),
          const SizedBox(height: 24),
          SwitchListTile(
            value: _premiumPronunciation,
            onChanged: _updatePremiumPronunciation,
            title: const Text(
              'Premium pronunciation phrases',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Include phrase-based pronunciation tasks in training flow. '
              'Requires an internet connection.',
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _hasInternet ? Icons.wifi : Icons.wifi_off,
                  size: 18,
                  color: _hasInternet
                      ? Colors.green.shade600
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Internet: ${_hasInternet ? 'Online' : 'Offline'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _hasInternet
                        ? Colors.green.shade700
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            const Text(
              'Debug',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TrainingTaskKind?>(
              initialValue: _debugForcedTaskKind,
              onChanged: _updateDebugForcedTaskKind,
              items: [
                const DropdownMenuItem<TrainingTaskKind?>(
                  value: null,
                  child: Text('No forced task'),
                ),
                ...TrainingTaskKind.values.map(
                  (kind) => DropdownMenuItem<TrainingTaskKind?>(
                    value: kind,
                    child: Text(kind.label),
                  ),
                ),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Force task type',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Forces the trainer to show only the selected task type.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Answer time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('${_answerSeconds}s'),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _answerSeconds.toDouble(),
            min: answerDurationMinSeconds.toDouble(),
            max: answerDurationMaxSeconds.toDouble(),
            divisions: (answerDurationMaxSeconds - answerDurationMinSeconds) ~/
                answerDurationStepSeconds,
            label: '${_answerSeconds}s',
            onChanged: (value) {
              final seconds = value.round();
              _updateAnswerSeconds(seconds);
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hint streak',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('$_hintStreakCount'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Show hint for the first N correct answers in a row.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _hintStreakCount.toDouble(),
            min: hintStreakMinCount.toDouble(),
            max: hintStreakMaxCount.toDouble(),
            divisions: hintStreakMaxCount - hintStreakMinCount,
            label: '$_hintStreakCount',
            onChanged: (value) {
              final count = value.round();
              _updateHintStreakCount(count);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Logs',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'In-memory buffer (last ${(logBuffer.byteLength / 1024).toStringAsFixed(1)} KB).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: logBuffer.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: logBuffer.text),
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Logs copied to clipboard.')),
                    );
                  },
            icon: const Icon(Icons.copy),
            label: const Text('Copy logs'),
          ),
          const SizedBox(height: 28),
          FilledButton.tonal(
            onPressed: _confirmReset,
            child: const Text('Reset progress'),
          ),
        ],
      ),
    );
  }
}
