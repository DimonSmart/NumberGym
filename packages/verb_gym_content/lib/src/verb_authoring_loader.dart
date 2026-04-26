import 'dart:convert';

import 'verb_authoring_models.dart';

class VerbAuthoringLoader {
  const VerbAuthoringLoader();

  VerbConceptDocument loadDocumentFromJsonString(String source) {
    final decoded = jsonDecode(source);
    return loadDocumentFromJsonMap(_asMap(decoded, r'$'));
  }

  VerbConceptDocument loadDocumentFromJsonMap(Map<String, Object?> json) {
    final schemaVersion = _asInt(
      _required(json, 'schemaVersion', r'$'),
      r'$.schemaVersion',
    );
    if (schemaVersion != 1) {
      throw FormatException(r'$.schemaVersion must be 1');
    }

    final languages = _asStringList(
      _required(json, 'languages', r'$'),
      r'$.languages',
    );
    if (languages.isEmpty) {
      throw FormatException(r'$.languages must not be empty');
    }

    final concept = _readConcept(
      _asMap(_required(json, 'entry', r'$'), r'$.entry'),
    );
    final exampleBlocksByTense = _readExampleBlocksByTense(
      _asMap(_required(json, 'examples', r'$'), r'$.examples'),
    );

    return VerbConceptDocument(
      schemaVersion: schemaVersion,
      languages: languages,
      concept: concept,
      exampleBlocksByTense: exampleBlocksByTense,
    );
  }

  VerbRuntimeConcept loadRuntimeConceptFromJsonString(String source) {
    return resolveDocument(loadDocumentFromJsonString(source));
  }

  VerbRuntimeConcept loadRuntimeConceptFromJsonMap(Map<String, Object?> json) {
    return resolveDocument(loadDocumentFromJsonMap(json));
  }

  VerbRuntimeCatalog loadRuntimeCatalogFromJsonStrings(
    Iterable<String> sources,
  ) {
    return VerbRuntimeCatalog(
      concepts: sources.map(loadRuntimeConceptFromJsonString),
    );
  }

  VerbRuntimeConcept resolveDocument(VerbConceptDocument document) {
    final examplesByTenseAndRole =
        <String, Map<String, List<VerbRuntimeExample>>>{};

    for (final tenseEntry in document.exampleBlocksByTense.entries) {
      final tenseId = tenseEntry.key;
      final examplesByRole = examplesByTenseAndRole.putIfAbsent(
        tenseId,
        () => <String, List<VerbRuntimeExample>>{},
      );

      for (final block in tenseEntry.value) {
        for (final role in block.roles) {
          final variant = block.variants[role];
          if (variant == null) {
            throw FormatException(
              'Missing variant "$role" for tense "$tenseId"',
            );
          }

          final text = _resolveText(block: block, variant: variant);
          final example = VerbRuntimeExample(
            conceptId: document.concept.id,
            tenseId: tenseId,
            role: role,
            formGroup: block.formGroup,
            text: text,
          );
          examplesByRole
              .putIfAbsent(role, () => <VerbRuntimeExample>[])
              .add(example);
        }
      }
    }

    return VerbRuntimeConcept(
      concept: document.concept,
      examplesByTenseAndRole: examplesByTenseAndRole,
    );
  }

  VerbConcept _readConcept(Map<String, Object?> json) {
    final id = _readConceptId(_required(json, 'id', r'$.entry'), r'$.entry.id');
    final meaning = <String, VerbConceptMeaning>{};
    final meaningJson = _asMap(
      _required(json, 'meaning', r'$.entry'),
      r'$.entry.meaning',
    );

    for (final entry in meaningJson.entries) {
      final path = '\$.entry.meaning.${entry.key}';
      final value = _asMap(entry.value, path);
      meaning[entry.key] = VerbConceptMeaning(
        short: _asString(_required(value, 'short', path), '$path.short'),
        description: _asString(
          _required(value, 'description', path),
          '$path.description',
        ),
      );
    }

    if (meaning.isEmpty) {
      throw FormatException(r'$.entry.meaning must not be empty');
    }

    return VerbConcept(id: id, meaning: meaning);
  }

  Map<String, List<VerbExampleBlock>> _readExampleBlocksByTense(
    Map<String, Object?> json,
  ) {
    final blocksByTense = <String, List<VerbExampleBlock>>{};

    for (final entry in json.entries) {
      final tenseId = entry.key;
      if (!VerbTenseIds.all.contains(tenseId)) {
        throw FormatException('Unknown tense "$tenseId"');
      }

      final blocks = <VerbExampleBlock>[];
      final blockJsonList = _asList(entry.value, '\$.examples.$tenseId');
      for (var index = 0; index < blockJsonList.length; index += 1) {
        final path = '\$.examples.$tenseId[$index]';
        blocks.add(
          _readExampleBlock(
            tenseId: tenseId,
            json: _asMap(blockJsonList[index], path),
            path: path,
          ),
        );
      }
      blocksByTense[tenseId] = blocks;
    }

    if (blocksByTense.isEmpty) {
      throw FormatException(r'$.examples must not be empty');
    }

    return blocksByTense;
  }

  VerbExampleBlock _readExampleBlock({
    required String tenseId,
    required Map<String, Object?> json,
    required String path,
  }) {
    final formGroup = _asStringMap(
      _required(json, 'formGroup', path),
      '$path.formGroup',
    );
    if (formGroup.isEmpty) {
      throw FormatException('$path.formGroup must not be empty');
    }
    final spanishFormGroup = formGroup['es'];
    if (spanishFormGroup != null &&
        !VerbFormGroupIds.spanish.contains(spanishFormGroup)) {
      throw FormatException(
        '$path.formGroup.es has unknown value "$spanishFormGroup"',
      );
    }

    final roles = _asStringList(_required(json, 'roles', path), '$path.roles');
    if (roles.isEmpty) {
      throw FormatException('$path.roles must not be empty');
    }
    for (final role in roles) {
      if (!VerbRoleIds.all.contains(role)) {
        throw FormatException('$path.roles contains unknown role "$role"');
      }
    }

    final pattern = _asStringMap(
      _required(json, 'pattern', path),
      '$path.pattern',
    );
    if (pattern.isEmpty) {
      throw FormatException('$path.pattern must not be empty');
    }

    final variants = <String, VerbExampleVariant>{};
    final variantsJson = _asMap(
      _required(json, 'variants', path),
      '$path.variants',
    );
    for (final entry in variantsJson.entries) {
      variants[entry.key] = _readExampleVariant(
        role: entry.key,
        json: _asMap(entry.value, '$path.variants.${entry.key}'),
        path: '$path.variants.${entry.key}',
      );
    }

    final roleSet = roles.toSet();
    for (final role in roles) {
      if (!variants.containsKey(role)) {
        throw FormatException('$path.variants is missing role "$role"');
      }
    }
    for (final role in variants.keys) {
      if (!roleSet.contains(role)) {
        throw FormatException('$path.variants.$role is not listed in roles');
      }
    }

    return VerbExampleBlock(
      tenseId: tenseId,
      formGroup: formGroup,
      roles: roles,
      pattern: pattern,
      variants: variants,
    );
  }

  VerbExampleVariant _readExampleVariant({
    required String role,
    required Map<String, Object?> json,
    required String path,
  }) {
    final text = json.containsKey('text')
        ? _asStringMap(json['text'], '$path.text')
        : const <String, String>{};
    final variables = <String, Map<String, String>>{};

    for (final entry in json.entries) {
      if (entry.key == 'text') {
        continue;
      }
      variables[entry.key] = _asStringMap(entry.value, '$path.${entry.key}');
    }

    return VerbExampleVariant(role: role, variables: variables, text: text);
  }

  Map<String, String> _resolveText({
    required VerbExampleBlock block,
    required VerbExampleVariant variant,
  }) {
    final text = <String, String>{};

    for (final patternEntry in block.pattern.entries) {
      text[patternEntry.key] = _substitutePattern(
        template: patternEntry.value,
        language: patternEntry.key,
        variant: variant,
      );
    }

    for (final translation in variant.text.entries) {
      if (text.containsKey(translation.key)) {
        throw FormatException(
          'Variant "${variant.role}" defines text.${translation.key}, '
          'but that language is already generated from pattern',
        );
      }
      text[translation.key] = translation.value;
    }

    return text;
  }

  String _substitutePattern({
    required String template,
    required String language,
    required VerbExampleVariant variant,
  }) {
    return template.replaceAllMapped(_templateVariablePattern, (match) {
      final variableName = match.group(1)!;
      final variable = variant.variables[variableName];
      if (variable == null) {
        throw FormatException(
          'Variant "${variant.role}" is missing variable "$variableName"',
        );
      }
      final value = variable[language];
      if (value == null) {
        throw FormatException(
          'Variant "${variant.role}" variable "$variableName" '
          'has no "$language" value',
        );
      }
      return value;
    });
  }
}

final RegExp _templateVariablePattern = RegExp(r'\{([^{}]+)\}');

Object? _required(Map<String, Object?> json, String key, String path) {
  if (!json.containsKey(key)) {
    throw FormatException('$path.$key is required');
  }
  return json[key];
}

VerbConceptId _readConceptId(Object? value, String path) {
  final id = _asString(value, path);
  try {
    return VerbConceptId(id);
  } on ArgumentError catch (error) {
    throw FormatException('$path is invalid: ${error.message}');
  }
}

Map<String, Object?> _asMap(Object? value, String path) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$path must have string keys');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }
  throw FormatException('$path must be an object');
}

List<Object?> _asList(Object? value, String path) {
  if (value is List) {
    return value.cast<Object?>();
  }
  throw FormatException('$path must be a list');
}

int _asInt(Object? value, String path) {
  if (value is int) {
    return value;
  }
  throw FormatException('$path must be an integer');
}

String _asString(Object? value, String path) {
  if (value is String) {
    return value;
  }
  throw FormatException('$path must be a string');
}

List<String> _asStringList(Object? value, String path) {
  return _asList(value, path)
      .asMap()
      .entries
      .map((entry) => _asString(entry.value, '$path[${entry.key}]'))
      .toList(growable: false);
}

Map<String, String> _asStringMap(Object? value, String path) {
  final map = _asMap(value, path);
  return <String, String>{
    for (final entry in map.entries)
      entry.key: _asString(entry.value, '$path.${entry.key}'),
  };
}
