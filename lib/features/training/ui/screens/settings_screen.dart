import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/learning_language.dart';
import '../../domain/language_router.dart';
import '../../domain/progress_manager.dart';
import '../../domain/services/internet_checker.dart';
import '../../domain/services/speech_service.dart';
import '../../domain/services/tts_service.dart';
import '../../domain/task_availability.dart';
import '../../domain/training_item.dart';
import '../../domain/training_task.dart';
import '../../languages/registry.dart';
import '../../../../core/logging/app_log_buffer.dart';
import '../../../../core/theme/app_palette.dart';

class SettingsScreen extends StatefulWidget {
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;
  final VoidCallback? onProgressChanged;

  const SettingsScreen({
    super.key,
    required this.settingsBox,
    required this.progressBox,
    this.onProgressChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  late final TtsServiceBase _ttsService;
  late final SpeechServiceBase _speechService;
  late final TaskAvailabilityRegistry _availabilityRegistry;
  late LearningLanguage _language;
  late int _answerSeconds;
  late int _hintStreakCount;
  late bool _premiumPronunciation;
  bool _ttsAvailable = true;
  bool _ttsLoading = false;
  List<TtsVoice> _ttsVoices = const [];
  String? _ttsVoiceId;
  bool _ttsPreviewing = false;
  bool _speechAvailable = true;
  bool _speechLoading = false;
  String? _speechStatusMessage;
  LearningMethod? _debugForcedLearningMethod;
  TrainingItemType? _debugForcedItemType;
  List<TrainingItemId> _debugCardIds = const [];
  TrainingItemId? _debugSelectedCardId;
  bool _debugCardsLoading = false;
  bool _debugMarkingAlmostLearned = false;
  bool _queueLoading = false;
  String? _queuePreview;
  Timer? _internetTimer;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _ttsService = TtsService();
    _speechService = SpeechService();
    _availabilityRegistry = TaskAvailabilityRegistry(
      providers: [
        SpeechTaskAvailabilityProvider(_speechService),
        TtsTaskAvailabilityProvider(_ttsService),
      ],
    );
    _language = _settingsRepository.readLearningLanguage();
    _answerSeconds = _settingsRepository.readAnswerDurationSeconds();
    _hintStreakCount = _settingsRepository.readHintStreakCount();
    _premiumPronunciation = _settingsRepository
        .readPremiumPronunciationEnabled();
    _loadTtsData();
    _loadSpeechAvailability();
    _refreshInternetStatus();
    _internetTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshInternetStatus(),
    );
    if (kDebugMode) {
      _debugForcedLearningMethod = _settingsRepository
          .readDebugForcedLearningMethod();
      _debugForcedItemType = _settingsRepository.readDebugForcedItemType();
      _loadDebugCardIds();
    }
  }

  @override
  void dispose() {
    _internetTimer?.cancel();
    _ttsService.dispose();
    _speechService.dispose();
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
    widget.onProgressChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Progress reset for ${LanguageRegistry.of(_language).label}.',
        ),
      ),
    );
  }

  Future<void> _updateLanguage(LearningLanguage value) async {
    setState(() {
      _language = value;
    });
    await _settingsRepository.setLearningLanguage(value);
    await _loadTtsData();
    await _loadSpeechAvailability();
    if (kDebugMode) {
      await _loadDebugCardIds();
    }
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
    final locale = LanguageRegistry.of(_language).locale;
    final availability = await _availabilityRegistry.check(
      LearningMethod.listening,
      TaskAvailabilityContext(
        language: _language,
        premiumPronunciationEnabled: _premiumPronunciation,
      ),
    );
    final available = availability.isAvailable;
    final voices = await _ttsService.listVoices();
    final filtered = filterVoicesByLocale(voices, locale);
    String? selected = _settingsRepository.readTtsVoiceId(_language);
    if (selected != null && filtered.every((voice) => voice.id != selected)) {
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

  Future<void> _loadSpeechAvailability() async {
    if (!mounted) return;
    setState(() {
      _speechLoading = true;
    });
    final availability = await _availabilityRegistry.check(
      LearningMethod.numberPronunciation,
      TaskAvailabilityContext(
        language: _language,
        premiumPronunciationEnabled: _premiumPronunciation,
      ),
    );
    if (!mounted) return;
    setState(() {
      _speechAvailable = availability.isAvailable;
      _speechStatusMessage = availability.message;
      _speechLoading = false;
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
    return LanguageRegistry.of(language).ttsPreviewText;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshInternetStatus() async {
    final hasConnection = await hasInternet();
    if (!mounted || _hasInternet == hasConnection) return;
    setState(() {
      _hasInternet = hasConnection;
    });
  }

  Future<void> _updateDebugForcedLearningMethod(LearningMethod? method) async {
    setState(() {
      _debugForcedLearningMethod = method;
    });
    await _settingsRepository.setDebugForcedLearningMethod(method);
  }

  Future<void> _updateDebugForcedItemType(TrainingItemType? type) async {
    setState(() {
      _debugForcedItemType = type;
    });
    await _settingsRepository.setDebugForcedItemType(type);
  }

  Future<void> _loadDebugCardIds() async {
    if (!mounted) return;
    setState(() {
      _debugCardsLoading = true;
    });
    try {
      final snapshot = await _loadQueueSnapshot();
      if (!mounted) return;
      final ids = List<TrainingItemId>.from(snapshot.all);
      final selected = ids.contains(_debugSelectedCardId)
          ? _debugSelectedCardId
          : (ids.isEmpty ? null : ids.first);
      setState(() {
        _debugCardIds = ids;
        _debugSelectedCardId = selected;
      });
    } catch (error) {
      _showSnack('Failed to load cards for debug: $error');
    } finally {
      if (mounted) {
        setState(() {
          _debugCardsLoading = false;
        });
      }
    }
  }

  void _selectDebugCard(TrainingItemId? id) {
    if (id == null) return;
    setState(() {
      _debugSelectedCardId = id;
    });
  }

  String _debugCardLabel(TrainingItemId id) {
    if (id.time != null) {
      return '${_itemTypeLabel(id.type)} | ${id.time!.displayText}';
    }
    if (id.number != null) {
      return '${_itemTypeLabel(id.type)} | ${id.number}';
    }
    return _itemTypeLabel(id.type);
  }

  Future<void> _markSelectedCardLearned() async {
    final selected = _debugSelectedCardId;
    if (selected == null || _debugMarkingAlmostLearned) return;
    setState(() {
      _debugMarkingAlmostLearned = true;
    });
    try {
      final progressById = await _progressRepository.loadAll(<TrainingItemId>[
        selected,
      ], language: _language);
      final current = progressById[selected] ?? CardProgress.empty;
      final updated = current.copyWith(
        learned: true,
        learnedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _progressRepository.save(selected, updated, language: _language);
      widget.onProgressChanged?.call();
      _showSnack('Card ${_formatQueueId(selected)} marked as learned.');
    } catch (error) {
      _showSnack('Failed to mark card as learned: $error');
    } finally {
      if (mounted) {
        setState(() {
          _debugMarkingAlmostLearned = false;
        });
      }
    }
  }

  String _itemTypeLabel(TrainingItemType type) {
    switch (type) {
      case TrainingItemType.digits:
        return 'Digits';
      case TrainingItemType.base:
        return 'Base';
      case TrainingItemType.hundreds:
        return 'Hundreds';
      case TrainingItemType.thousands:
        return 'Thousands';
      case TrainingItemType.timeExact:
        return 'Time (exact)';
      case TrainingItemType.timeQuarter:
        return 'Time (quarter)';
      case TrainingItemType.timeHalf:
        return 'Time (half)';
      case TrainingItemType.timeRandom:
        return 'Time (random)';
    }
  }

  String _formatQueueId(TrainingItemId id) {
    if (id.time != null) {
      return '${id.type.name}:${id.time!.displayText}';
    }
    final number = id.number;
    final suffix = number != null ? number.toString() : '*';
    return '${id.type.name}:$suffix';
  }

  CardProgress _progressFor(
    LearningQueueDebugSnapshot snapshot,
    TrainingItemId id,
  ) {
    return snapshot.progressById[id] ?? CardProgress.empty;
  }

  int _totalWrong(CardProgress progress) {
    return progress.totalWrong;
  }

  int _sumAttempts(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _progressFor(snapshot, id).totalAttempts;
    }
    return total;
  }

  int _sumCorrect(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _progressFor(snapshot, id).totalCorrect;
    }
    return total;
  }

  int _sumWrong(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _totalWrong(_progressFor(snapshot, id));
    }
    return total;
  }

  int _sumSkipped(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _progressFor(snapshot, id).totalSkipped;
    }
    return total;
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatQueueCardLine(
    TrainingItemId id,
    LearningQueueDebugSnapshot snapshot,
  ) {
    final progress = _progressFor(snapshot, id);
    final lastAnswerAt = progress.lastCluster?.lastAnswerAt ?? 0;
    final lastAnswerText = lastAnswerAt <= 0
        ? '-'
        : _formatDateTime(DateTime.fromMillisecondsSinceEpoch(lastAnswerAt));
    final status = progress.learned ? 'learned' : 'learning';
    final correct = progress.totalCorrect;
    final wrong = _totalWrong(progress);
    final skipped = progress.totalSkipped;
    final attempts = progress.totalAttempts;
    final accuracy = attempts == 0 ? 0.0 : correct / attempts;
    final weight = snapshot.weightById[id] ?? 0;
    return '${_formatQueueId(id)} | weight: ${weight.toStringAsFixed(3)} '
        '| $status | acc: ${(accuracy * 100).toStringAsFixed(1)}% '
        '| c/w/s: $correct/$wrong/$skipped | attempts: $attempts '
        '| last: $lastAnswerText';
  }

  String _formatQueuePreview(LearningQueueDebugSnapshot snapshot) {
    final language = snapshot.language ?? _language;
    final languageLabel = LanguageRegistry.of(language).label;
    final totalAttempts = _sumAttempts(snapshot.all, snapshot);
    final totalCorrect = _sumCorrect(snapshot.all, snapshot);
    final totalWrong = _sumWrong(snapshot.all, snapshot);
    final totalSkipped = _sumSkipped(snapshot.all, snapshot);
    final prioritizedHead = snapshot.prioritized
        .take(8)
        .map((id) => _formatQueueId(id))
        .join(', ');
    final prioritizedSuffix = snapshot.prioritized.length > 8 ? ', ...' : '';
    final attemptsRemaining =
        (snapshot.dailyAttemptLimit - snapshot.dailyAttemptsToday).clamp(
          0,
          snapshot.dailyAttemptLimit,
        );
    final newCardsRemaining =
        (snapshot.dailyNewCardsLimit - snapshot.dailyNewCardsToday).clamp(
          0,
          snapshot.dailyNewCardsLimit,
        );
    return [
      'Language: $languageLabel',
      'Daily attempts: ${snapshot.dailyAttemptsToday}/${snapshot.dailyAttemptLimit} '
          '(remaining $attemptsRemaining)',
      'Daily new cards: ${snapshot.dailyNewCardsToday}/${snapshot.dailyNewCardsLimit} '
          '(remaining $newCardsRemaining)',
      'Top priority: ${prioritizedHead.isEmpty ? 'empty' : '$prioritizedHead$prioritizedSuffix'}',
      'Answers: $totalAttempts (correct $totalCorrect, '
          'wrong $totalWrong, skipped $totalSkipped)',
    ].join('\n');
  }

  String _formatQueueClipboard(LearningQueueDebugSnapshot snapshot) {
    final language = snapshot.language ?? _language;
    final languageLabel = LanguageRegistry.of(language).label;
    final now = DateTime.now();
    final totalAttempts = _sumAttempts(snapshot.all, snapshot);
    final totalCorrect = _sumCorrect(snapshot.all, snapshot);
    final totalWrong = _sumWrong(snapshot.all, snapshot);
    final totalSkipped = _sumSkipped(snapshot.all, snapshot);
    const priorityCopyLimit = 500;
    final buffer = StringBuffer()
      ..writeln('Generated at: ${_formatDateTime(now)}')
      ..writeln('Language: $languageLabel')
      ..writeln('Total cards: ${snapshot.all.length}')
      ..writeln(
        'Daily attempts: ${snapshot.dailyAttemptsToday}/${snapshot.dailyAttemptLimit}',
      )
      ..writeln(
        'Daily new cards: ${snapshot.dailyNewCardsToday}/${snapshot.dailyNewCardsLimit}',
      )
      ..writeln(
        'Answers total: $totalAttempts '
        '(correct: $totalCorrect, wrong: $totalWrong, skipped: $totalSkipped)',
      )
      ..writeln('Priority list (${snapshot.prioritized.length}):');
    final prioritizedItems = snapshot.prioritized
        .take(priorityCopyLimit)
        .toList();
    for (var i = 0; i < prioritizedItems.length; i++) {
      buffer.writeln(
        '  ${i + 1}. '
        '${_formatQueueCardLine(prioritizedItems[i], snapshot)}',
      );
    }
    final remaining = snapshot.prioritized.length - prioritizedItems.length;
    if (remaining > 0) {
      buffer.writeln('  ... +$remaining more');
    }
    return buffer.toString();
  }

  Future<LearningQueueDebugSnapshot> _loadQueueSnapshot() async {
    final languageRouter = LanguageRouter(
      settingsRepository: _settingsRepository,
    );
    final language = languageRouter.currentLanguage;
    final manager = ProgressManager(
      progressRepository: _progressRepository,
      languageRouter: languageRouter,
    );
    await manager.loadProgress(language);
    return manager.debugQueueSnapshot();
  }

  Future<void> _copyQueueToClipboard() async {
    if (_queueLoading) return;
    setState(() {
      _queueLoading = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final snapshot = await _loadQueueSnapshot();
      final preview = _formatQueuePreview(snapshot);
      final clipboardText = _formatQueueClipboard(snapshot);
      await Clipboard.setData(ClipboardData(text: clipboardText));
      if (!mounted) return;
      setState(() {
        _queuePreview = preview;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Card priorities copied to clipboard.')),
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to copy queue: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _queueLoading = false;
        });
      }
    }
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
                    child: Text(LanguageRegistry.of(language).label),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
                      ? AppPalette.deepBlue
                      : theme.colorScheme.error,
                ),
              const SizedBox(width: 8),
              Text(
                _ttsLoading
                    ? 'TTS: Checking...'
                    : 'TTS: ${_ttsAvailable ? 'Available' : 'Unavailable'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _ttsAvailable
                      ? AppPalette.deepBlue
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
              'No voices found for ${LanguageRegistry.of(_language).label}.',
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
                  onPressed: _ttsAvailable && !_ttsPreviewing
                      ? _previewTtsVoice
                      : null,
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
          const Text(
            'Speech recognition',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_speechLoading)
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
                  _speechAvailable ? Icons.mic : Icons.mic_off,
                  size: 18,
                  color: _speechAvailable
                      ? AppPalette.deepBlue
                      : theme.colorScheme.error,
                ),
              const SizedBox(width: 8),
              Text(
                _speechLoading
                    ? 'Speech recognition: Checking...'
                    : 'Speech recognition: ${_speechAvailable ? 'Available' : 'Unavailable'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _speechAvailable
                      ? AppPalette.deepBlue
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!_speechAvailable &&
              !_speechLoading &&
              _speechStatusMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _speechStatusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
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
                      ? AppPalette.deepBlue
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Internet: ${_hasInternet ? 'Online' : 'Offline'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _hasInternet
                        ? AppPalette.deepBlue
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            const Text('Debug', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<TrainingItemType?>(
              initialValue: _debugForcedItemType,
              onChanged: _updateDebugForcedItemType,
              items: [
                const DropdownMenuItem<TrainingItemType?>(
                  value: null,
                  child: Text('No forced card type'),
                ),
                ...TrainingItemType.values.map(
                  (type) => DropdownMenuItem<TrainingItemType?>(
                    value: type,
                    child: Text(_itemTypeLabel(type)),
                  ),
                ),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Force card type',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Filters the training pool to only the selected card type.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LearningMethod?>(
              initialValue: _debugForcedLearningMethod,
              onChanged: _updateDebugForcedLearningMethod,
              items: [
                const DropdownMenuItem<LearningMethod?>(
                  value: null,
                  child: Text('No forced learning method'),
                ),
                ...LearningMethod.values.map(
                  (method) => DropdownMenuItem<LearningMethod?>(
                    value: method,
                    child: Text(method.label),
                  ),
                ),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Force learning method',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Forces the trainer to use only the selected learning method.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_debugCardsLoading)
              const LinearProgressIndicator()
            else if (_debugCardIds.isEmpty)
              Text(
                'No cards found for debug actions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              DropdownButtonFormField<TrainingItemId>(
                initialValue: _debugSelectedCardId,
                onChanged: _selectDebugCard,
                isExpanded: true,
                items: _debugCardIds
                    .map(
                      (id) => DropdownMenuItem<TrainingItemId>(
                        value: id,
                        child: Text(
                          _debugCardLabel(id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => _debugCardIds
                    .map(
                      (id) => Text(
                        _debugCardLabel(id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select card',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _debugMarkingAlmostLearned
                    ? null
                    : _markSelectedCardLearned,
                icon: _debugMarkingAlmostLearned
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      )
                    : const Icon(Icons.school),
                label: Text(
                  _debugMarkingAlmostLearned
                      ? 'Updating...'
                      : 'Mark selected card learned',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Debug shortcut: marks this card as learned immediately.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _queueLoading ? null : _copyQueueToClipboard,
              icon: _queueLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    )
                  : const Icon(Icons.copy_all),
              label: Text(
                _queueLoading ? 'Copying...' : 'Copy card priorities',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Copies current probabilistic priority list to clipboard.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_queuePreview != null) ...[
              const SizedBox(height: 6),
              Text(
                _queuePreview!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
            divisions:
                (answerDurationMaxSeconds - answerDurationMinSeconds) ~/
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
          const Text('Logs', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      const SnackBar(
                        content: Text('Logs copied to clipboard.'),
                      ),
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
