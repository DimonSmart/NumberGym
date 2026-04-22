import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../app_definition.dart';
import '../exercise_models.dart';
import '../progress_manager.dart';
import '../progress_repository.dart';
import '../settings_repository.dart';
import '../training/data/card_progress.dart';
import 'widgets/training_background.dart';

class DebugSettingsScreen extends StatefulWidget {
  const DebugSettingsScreen({
    super.key,
    required this.appDefinition,
    required this.settingsBox,
    required this.progressBox,
    this.onProgressChanged,
  });

  final TrainingAppDefinition appDefinition;
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;
  final VoidCallback? onProgressChanged;

  @override
  State<DebugSettingsScreen> createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen> {
  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  String? _forcedMode;
  String? _forcedFamilyKey;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _forcedMode = _settingsRepository.readDebugForcedMode();
    _forcedFamilyKey = _settingsRepository.readDebugForcedFamilyKey();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debug')),
        body: const Center(child: Text('Debug menu is available only in debug mode.')),
      );
    }

    final language = _settingsRepository.readLearningLanguage();
    final families = widget.appDefinition.catalog.build(language).familiesByKey.values.toList()
      ..sort((left, right) => left.label.compareTo(right.label));

    return Scaffold(
      body: TrainingBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Debug',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _forcedFamilyKey,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No forced family'),
                  ),
                  ...families.map(
                    (family) => DropdownMenuItem<String?>(
                      value: family.storageKey,
                      child: Text(family.label),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() {
                    _forcedFamilyKey = value;
                  });
                  await _settingsRepository.setDebugForcedFamilyKey(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Force family',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _forcedMode,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No forced mode'),
                  ),
                  ...ExerciseMode.values.map(
                    (mode) => DropdownMenuItem<String?>(
                      value: mode.name,
                      child: Text(mode.label),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() {
                    _forcedMode = value;
                  });
                  await _settingsRepository.setDebugForcedMode(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Force mode',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _copyQueueToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('Copy queue snapshot'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyQueueToClipboard() async {
    final manager = ProgressManager(
      progressRepository: _progressRepository,
      catalog: widget.appDefinition.catalog,
    );
    final language = _settingsRepository.readLearningLanguage();
    await manager.loadProgress(language);
    final snapshot = manager.debugQueueSnapshot();
    final buffer = StringBuffer()
      ..writeln('Language: ${widget.appDefinition.profileOf(language).code}')
      ..writeln('Cards: ${snapshot.all.length}');
    for (final card in snapshot.prioritized.take(20)) {
      final progress =
          snapshot.progressByKey[card.progressId.storageKey] ?? CardProgress.empty;
      buffer.writeln(
        '${card.progressId.storageKey} | attempts=${progress.totalAttempts} | learned=${progress.learned}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Queue snapshot copied.')),
    );
  }
}
