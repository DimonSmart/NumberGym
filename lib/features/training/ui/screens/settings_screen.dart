import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/learning_language.dart';

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
              'Include phrase-based pronunciation tasks in training flow.',
            ),
          ),
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
