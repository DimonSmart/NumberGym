import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../app_definition.dart';
import '../app_config.dart';
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
  late LearningLanguage _baseLanguage;
  late LearningLanguage _learningLanguage;
  late bool _premiumPronunciation;
  bool _ttsAvailable = true;
  bool _speechAvailable = true;
  List<TtsVoice> _ttsVoices = const [];
  String? _ttsVoiceId;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository.forApp(
      widget.settingsBox,
      widget.appDefinition.config,
    );
    _progressRepository = ProgressRepository(widget.progressBox);
    _ttsService = TtsService();
    _speechService = SpeechService();
    _baseLanguage = _supportedLanguageOrDefault(
      _settingsRepository.readBaseLanguage(),
      widget.appDefinition.config.defaultBaseLanguage,
    );
    _learningLanguage = _supportedLanguageOrDefault(
      _settingsRepository.readLearningLanguage(),
      widget.appDefinition.config.defaultLearningLanguage,
    );
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
    final profile = widget.appDefinition.profileOf(_learningLanguage);
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
      _ttsVoiceId = _settingsRepository.readTtsVoiceId(_learningLanguage);
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
    await _progressRepository.reset(language: _learningLanguage);
    await _settingsRepository.resetProgressForLanguage(_learningLanguage);
    widget.onProgressChanged?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Progress reset.')));
  }

  Future<void> _updateBaseLanguage(LearningLanguage language) async {
    setState(() {
      _baseLanguage = language;
    });
    await _settingsRepository.setBaseLanguage(language);
    widget.onProgressChanged?.call();
  }

  Future<void> _updateLearningLanguage(LearningLanguage language) async {
    setState(() {
      _learningLanguage = language;
    });
    await _settingsRepository.setLearningLanguage(language);
    await _loadAvailability();
    widget.onProgressChanged?.call();
  }

  LearningLanguage _supportedLanguageOrDefault(
    LearningLanguage language,
    LearningLanguage defaultLanguage,
  ) {
    if (widget.appDefinition.supportedLanguages.contains(language)) {
      return language;
    }
    if (widget.appDefinition.supportedLanguages.contains(defaultLanguage)) {
      return defaultLanguage;
    }
    return widget.appDefinition.supportedLanguages.first;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.appDefinition.profileOf(_learningLanguage);
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
              ..._buildLanguageFields(),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _premiumPronunciation,
                onChanged: (value) async {
                  setState(() {
                    _premiumPronunciation = value;
                  });
                  await _settingsRepository.setPremiumPronunciationEnabled(
                    value,
                  );
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
                    await _settingsRepository.setTtsVoiceId(
                      _learningLanguage,
                      value,
                    );
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

  List<Widget> _buildLanguageFields() {
    if (widget.appDefinition.config.languageSettingsMode ==
        LanguageSettingsMode.baseAndLearningLanguage) {
      return <Widget>[
        _buildLanguageDropdown(
          label: 'Base language',
          value: _baseLanguage,
          onChanged: _updateBaseLanguage,
        ),
        const SizedBox(height: 16),
        _buildLanguageDropdown(
          label: 'Learning language',
          value: _learningLanguage,
          onChanged: _updateLearningLanguage,
        ),
      ];
    }

    return <Widget>[
      _buildLanguageDropdown(
        label: 'Language',
        value: _learningLanguage,
        onChanged: _updateLearningLanguage,
      ),
    ];
  }

  Widget _buildLanguageDropdown({
    required String label,
    required LearningLanguage value,
    required Future<void> Function(LearningLanguage language) onChanged,
  }) {
    return DropdownButtonFormField<LearningLanguage>(
      initialValue: value,
      items: widget.appDefinition.supportedLanguages
          .map(
            (language) => DropdownMenuItem(
              value: language,
              child: Text(widget.appDefinition.profileOf(language).label),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
