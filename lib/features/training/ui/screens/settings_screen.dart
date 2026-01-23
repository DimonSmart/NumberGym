import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/learning_language.dart';
import '../../domain/services/internet_checker.dart';
import '../../domain/training_task.dart';

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
  late LearningLanguage _language;
  late int _answerSeconds;
  late int _hintStreakCount;
  late bool _premiumPronunciation;
  TrainingTaskKind? _debugForcedTaskKind;
  Timer? _internetTimer;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _language = _settingsRepository.readLearningLanguage();
    _answerSeconds = _settingsRepository.readAnswerDurationSeconds();
    _hintStreakCount = _settingsRepository.readHintStreakCount();
    _premiumPronunciation =
      _settingsRepository.readPremiumPronunciationEnabled();
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
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This will clear all progress for every card.',
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
    await _progressRepository.reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress reset.')),
    );
  }

  Future<void> _updateLanguage(LearningLanguage value) async {
    setState(() {
      _language = value;
    });
    await _settingsRepository.setLearningLanguage(value);
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
