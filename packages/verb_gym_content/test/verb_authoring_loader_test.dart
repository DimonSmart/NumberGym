import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

void main() {
  const loader = VerbAuthoringLoader();

  test('loads concept document with concept id as the primary identity', () {
    final document = loader.loadDocumentFromJsonString(_tiredJson);

    expect(document.schemaVersion, 1);
    expect(document.languages, <String>['en', 'es']);
    expect(document.concept.id, VerbConceptId('be_tired'));
    expect(document.concept.meaning['en']!.short, 'to be tired');
    expect(
      document.exampleBlocksByTense[VerbTenseIds.presentIndicative],
      hasLength(1),
    );
  });

  test('resolves pattern substitutions into runtime examples', () {
    final runtime = loader.loadRuntimeConceptFromJsonString(_tiredJson);
    final examplesByRole =
        runtime.examplesByTenseAndRole[VerbTenseIds.presentIndicative]!;
    final sheExample = examplesByRole[VerbRoleIds.she]!.single;

    expect(sheExample.conceptId, VerbConceptId('be_tired'));
    expect(sheExample.formGroup['es'], VerbFormGroupIds.thirdSingular);
    expect(sheExample.text['es'], 'Ella est\u00e1 cansada.');
    expect(sheExample.text['en'], 'She is tired.');

    final runtimeJson = runtime.toJson();
    final examplesJson = runtimeJson['examples']! as Map<String, Object?>;
    final presentJson =
        examplesJson[VerbTenseIds.presentIndicative]! as Map<String, Object?>;
    final sheJson = presentJson[VerbRoleIds.she]! as List<Object?>;

    expect(runtimeJson['entryId'], 'be_tired');
    expect(sheJson.single, <String, Object?>{
      'es': 'Ella est\u00e1 cansada.',
      'en': 'She is tired.',
    });
  });

  test('throws when a pattern variable is missing from a variant', () {
    expect(
      () => loader.loadRuntimeConceptFromJsonString(_missingVariableJson),
      throwsA(isA<FormatException>()),
    );
  });

  test('loads all authoring assets from the index', () async {
    final authoringDirectory = _authoringAssetDirectory();
    final index = _readAuthoringIndex(authoringDirectory);

    expect(index, _expectedConceptIds.map((id) => '$id.json').toList());

    final runtimeCatalog = await VerbAuthoringAssetLoader(
      bundle: _FileAssetBundle(authoringDirectory),
    ).loadRuntimeCatalog();

    expect(runtimeCatalog.conceptsById, hasLength(111));
    expect(
      runtimeCatalog.conceptsById.keys.map((id) => id.value),
      _expectedConceptIds,
    );

    for (final fileName in index) {
      final file = File.fromUri(authoringDirectory.uri.resolve(fileName));
      final runtime = loader.loadRuntimeConceptFromJsonString(
        file.readAsStringSync(),
      );
      expect(runtime.id.value, _fileStem(file));
      _expectTenseExamples(runtime, VerbTenseIds.presentIndicative);
      _expectTenseExamples(runtime, VerbTenseIds.preterite);
      _expectTenseExamples(runtime, VerbTenseIds.futureSimple);
      for (final example in runtime.examples) {
        expect(example.text['en'], isNotEmpty);
        expect(example.text['es'], isNotEmpty);
      }
    }
  });
}

Directory _authoringAssetDirectory() {
  return Directory(
    _findWorkspaceRoot().uri
        .resolve('packages/verb_gym_content/assets/authoring/')
        .toFilePath(),
  );
}

List<String> _readAuthoringIndex(Directory directory) {
  final source = File.fromUri(
    directory.uri.resolve('index.json'),
  ).readAsStringSync();
  return (jsonDecode(source) as List).cast<String>();
}

void _expectTenseExamples(VerbRuntimeConcept runtime, String tenseId) {
  final examplesByRole = runtime.examplesByTenseAndRole[tenseId];
  expect(examplesByRole, isNotNull, reason: runtime.id.value);
  expect(
    examplesByRole!.values.expand((examples) => examples),
    hasLength(9),
    reason: '${runtime.id.value} $tenseId',
  );
}

Directory _findWorkspaceRoot() {
  var directory = Directory.current;
  while (true) {
    final authoringDirectory = directory.uri
        .resolve('packages/verb_gym_content/assets/authoring/')
        .toFilePath();
    if (Directory(authoringDirectory).existsSync()) {
      return directory;
    }

    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'Could not find workspace root from ${Directory.current}',
      );
    }
    directory = parent;
  }
}

String _fileStem(File file) {
  final name = file.uri.pathSegments.last;
  return name.substring(0, name.length - '.json'.length);
}

class _FileAssetBundle extends CachingAssetBundle {
  _FileAssetBundle(this.directory);

  final Directory directory;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError('String assets only');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final prefix = '$defaultVerbAuthoringAssetRoot/';
    if (!key.startsWith(prefix)) {
      throw ArgumentError.value(key, 'key', 'Unexpected asset key');
    }
    final fileName = key.substring(prefix.length);
    return File.fromUri(directory.uri.resolve(fileName)).readAsString();
  }
}

const List<String> _expectedConceptIds = <String>[
  'eat_meal',
  'drink_water',
  'sleep_at_night',
  'wake_up',
  'get_up',
  'sit_down',
  'stand_up',
  'take_shower',
  'wash_hands',
  'wear_jacket',
  'clean_room',
  'cook_dinner',
  'prepare_breakfast',
  'order_coffee',
  'buy_food',
  'pay_bill',
  'walk_to_work',
  'run_in_park',
  'arrive_at_work',
  'leave_home',
  'return_home',
  'enter_room',
  'exit_room',
  'travel_to_city',
  'live_in_city',
  'go_shopping',
  'take_bus',
  'drive_car',
  'ride_bike',
  'visit_friend',
  'stay_home',
  'come_here',
  'open_door',
  'close_door',
  'use_phone',
  'charge_phone',
  'turn_on_light',
  'turn_off_light',
  'put_item',
  'take_item',
  'bring_item',
  'carry_bag',
  'give_item',
  'receive_item',
  'speak_spanish',
  'say_hello',
  'ask_question',
  'answer_question',
  'ask_for_help',
  'call_friend',
  'send_message',
  'write_email',
  'tell_story',
  'invite_friend',
  'explain_problem',
  'show_photo',
  'read_book',
  'listen_to_music',
  'watch_movie',
  'understand_lesson',
  'learn_word',
  'remember_name',
  'forget_name',
  'study_lesson',
  'teach_word',
  'work_today',
  'start_task',
  'continue_task',
  'finish_task',
  'stop_task',
  'wait_for_bus',
  'meet_friend',
  'help_person',
  'need_help',
  'choose_option',
  'change_plan',
  'decide_now',
  'try_again',
  'plan_trip',
  'look_for_keys',
  'find_keys',
  'lose_keys',
  'take_photo',
  'look_at_photo',
  'see_person',
  'hear_noise',
  'know_person',
  'know_fact',
  'think_about_problem',
  'believe_story',
  'notice_mistake',
  'recognize_person',
  'feel_good',
  'feel_bad',
  'be_happy',
  'be_busy',
  'be_late',
  'be_ready',
  'have_pain',
  'need_doctor',
  'rest_at_home',
  'like_food',
  'prefer_coffee',
  'want_coffee',
  'can_do',
  'have_time',
  'have_money',
  'have_to_work',
  'be_from_country',
  'be_at_home',
  'there_is_problem',
];

String get _tiredJson {
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'languages': <String>['en', 'es'],
    'entry': <String, Object?>{
      'id': 'be_tired',
      'meaning': <String, Object?>{
        'en': <String, String>{
          'short': 'to be tired',
          'description': 'To feel tired.',
        },
        'es': <String, String>{
          'short': 'estar cansado',
          'description': 'Sentir cansancio.',
        },
      },
    },
    'examples': <String, Object?>{
      VerbTenseIds.presentIndicative: <Object?>[
        <String, Object?>{
          'formGroup': <String, String>{'es': VerbFormGroupIds.thirdSingular},
          'roles': <String>[VerbRoleIds.he, VerbRoleIds.she],
          'pattern': <String, String>{'es': '{subject} est\u00e1 {adjective}.'},
          'variants': <String, Object?>{
            VerbRoleIds.he: <String, Object?>{
              'subject': <String, String>{'es': 'El'},
              'adjective': <String, String>{'es': 'cansado'},
              'text': <String, String>{'en': 'He is tired.'},
            },
            VerbRoleIds.she: <String, Object?>{
              'subject': <String, String>{'es': 'Ella'},
              'adjective': <String, String>{'es': 'cansada'},
              'text': <String, String>{'en': 'She is tired.'},
            },
          },
        },
      ],
    },
  });
}

String get _missingVariableJson {
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'languages': <String>['en', 'es'],
    'entry': <String, Object?>{
      'id': 'be_tired',
      'meaning': <String, Object?>{
        'en': <String, String>{
          'short': 'to be tired',
          'description': 'To feel tired.',
        },
      },
    },
    'examples': <String, Object?>{
      VerbTenseIds.presentIndicative: <Object?>[
        <String, Object?>{
          'formGroup': <String, String>{'es': VerbFormGroupIds.thirdSingular},
          'roles': <String>[VerbRoleIds.she],
          'pattern': <String, String>{'es': '{subject} est\u00e1 {adjective}.'},
          'variants': <String, Object?>{
            VerbRoleIds.she: <String, Object?>{
              'subject': <String, String>{'es': 'Ella'},
              'text': <String, String>{'en': 'She is tired.'},
            },
          },
        },
      ],
    },
  });
}
