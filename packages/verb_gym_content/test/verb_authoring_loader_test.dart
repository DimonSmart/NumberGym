import 'dart:convert';
import 'dart:io';

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

  test('loads all generated authoring files', () {
    final authoringDirectory = _findWorkspaceRoot().uri
        .resolve('apps/verb_gym/specs/authoring/')
        .toFilePath();
    final files =
        Directory(authoringDirectory)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(files, hasLength(10));

    final runtimeCatalog = loader.loadRuntimeCatalogFromJsonStrings(
      files.map((file) => file.readAsStringSync()),
    );

    expect(runtimeCatalog.conceptsById, hasLength(10));
    expect(
      runtimeCatalog.conceptsById.keys.map((id) => id.value),
      containsAll(<String>[
        'be_hungry',
        'be_cold',
        'be_tired',
        'be_afraid',
        'be_right',
        'have_possession',
        'have_age',
        'have_to_do',
        'want_to_do',
        'go_to_place',
      ]),
    );

    for (final file in files) {
      final runtime = loader.loadRuntimeConceptFromJsonString(
        file.readAsStringSync(),
      );
      expect(runtime.id.value, _fileStem(file));
      expect(runtime.examples, hasLength(9));
      for (final example in runtime.examples) {
        expect(example.text['en'], isNotEmpty);
        expect(example.text['es'], isNotEmpty);
      }
    }
  });
}

Directory _findWorkspaceRoot() {
  var directory = Directory.current;
  while (true) {
    final authoringDirectory = directory.uri
        .resolve('apps/verb_gym/specs/authoring/')
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
