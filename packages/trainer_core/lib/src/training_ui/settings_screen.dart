import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../app_definition.dart';
import '../progress_repository.dart';
import '../settings_repository.dart';
import '../trainer_services.dart';
import '../training/data/card_progress.dart';
import '../training/domain/learning_language.dart';
import 'widgets/training_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  late final TtsServiceBase _ttsService;
  late final SpeechServiceBase _speechService;
  late LearningLanguage _language;
  late bool _premiumPronunciation;
  bool _ttsAvailable = true;
  bool _speechAvailable = true;
  List<TtsVoice> _ttsVoices = const [];
  String? _ttsVoiceId;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _ttsService = TtsService();
    _speechService = SpeechService();
    _language = _settingsRepository.readLearningLanguage();
    if (!widget.appDefinition.supportedLanguages.contains(_language)) {
      _language = widget.appDefinition.supportedLanguages.first;
    }
    _premiumPronunciation = _settingsRepository
        .readPremiumPronunciationEnabled();
    _loadAvailability();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    final profile = widget.appDefinition.profileOf(_language);
    final voices = await _ttsService.listVoices();
    final filtered = filterVoicesByLocale(voices, profile.locale);
    final ttsAvailable = await _ttsService.isLanguageAvailable(profile.locale);
    final speechAvailability = await _speechService.initialize(
      onError: (_) {},
      onStatus: (_) {},
      requestPermission: false,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _ttsVoices = filtered;
      _ttsAvailable = ttsAvailable;
      _speechAvailable = speechAvailability.ready;
      _ttsVoiceId = _settingsRepository.readTtsVoiceId(_language);
    });
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
    if (confirmed != true) {
      return;
    }
    await _progressRepository.reset(language: _language);
    await _settingsRepository.resetProgressForLanguage(_language);
    widget.onProgressChanged?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress reset.')),
    );
  }

  Future<void> _updateLanguage(LearningLanguage language) async {
    setState(() {
      _language = language;
    });
    await _settingsRepository.setLearningLanguage(language);
    await _loadAvailability();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.appDefinition.profileOf(_language);
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
                    'Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LearningLanguage>(
                initialValue: _language,
                items: widget.appDefinition.supportedLanguages
                    .map(
                      (language) => DropdownMenuItem(
                        value: language,
                        child: Text(
                          widget.appDefinition.profileOf(language).label,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _updateLanguage(value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _premiumPronunciation,
                onChanged: (value) async {
                  setState(() {
                    _premiumPronunciation = value;
                  });
                  await _settingsRepository.setPremiumPronunciationEnabled(value);
                },
                title: const Text('Premium pronunciation review'),
              ),
              ListTile(
                title: const Text('TTS'),
                subtitle: Text(
                  _ttsAvailable
                      ? 'Available for ${profile.label}'
                      : 'Unavailable for ${profile.label}',
                ),
              ),
              if (_ttsVoices.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _ttsVoiceId,
                  items: _ttsVoices
                      .map(
                        (voice) => DropdownMenuItem(
                          value: voice.id,
                          child: Text(voice.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    setState(() {
                      _ttsVoiceId = value;
                    });
                    await _settingsRepository.setTtsVoiceId(_language, value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Voice',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Speech recognition'),
                subtitle: Text(_speechAvailable ? 'Available' : 'Unavailable'),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _confirmReset,
                child: const Text('Reset progress'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
