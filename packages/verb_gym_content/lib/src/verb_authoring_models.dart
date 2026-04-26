class VerbConceptId implements Comparable<VerbConceptId> {
  VerbConceptId(String value) : value = _validateConceptId(value);

  final String value;

  @override
  int compareTo(VerbConceptId other) => value.compareTo(other.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return other is VerbConceptId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class VerbConcept {
  VerbConcept({
    required this.id,
    required Map<String, VerbConceptMeaning> meaning,
  }) : meaning = Map<String, VerbConceptMeaning>.unmodifiable(meaning);

  final VerbConceptId id;
  final Map<String, VerbConceptMeaning> meaning;
}

class VerbConceptMeaning {
  const VerbConceptMeaning({required this.short, required this.description});

  final String short;
  final String description;
}

class VerbConceptDocument {
  VerbConceptDocument({
    required this.schemaVersion,
    required List<String> languages,
    required this.concept,
    required Map<String, List<VerbExampleBlock>> exampleBlocksByTense,
  }) : languages = List<String>.unmodifiable(languages),
       exampleBlocksByTense = _unmodifiableStringListMap<VerbExampleBlock>(
         exampleBlocksByTense,
       );

  final int schemaVersion;
  final List<String> languages;
  final VerbConcept concept;
  final Map<String, List<VerbExampleBlock>> exampleBlocksByTense;
}

class VerbExampleBlock {
  VerbExampleBlock({
    required this.tenseId,
    required Map<String, String> formGroup,
    required List<String> roles,
    required Map<String, String> pattern,
    required Map<String, VerbExampleVariant> variants,
  }) : formGroup = Map<String, String>.unmodifiable(formGroup),
       roles = List<String>.unmodifiable(roles),
       pattern = Map<String, String>.unmodifiable(pattern),
       variants = Map<String, VerbExampleVariant>.unmodifiable(variants);

  final String tenseId;
  final Map<String, String> formGroup;
  final List<String> roles;
  final Map<String, String> pattern;
  final Map<String, VerbExampleVariant> variants;
}

class VerbExampleVariant {
  VerbExampleVariant({
    required this.role,
    required Map<String, Map<String, String>> variables,
    required Map<String, String> text,
  }) : variables = _unmodifiableStringMapMap(variables),
       text = Map<String, String>.unmodifiable(text);

  final String role;
  final Map<String, Map<String, String>> variables;
  final Map<String, String> text;
}

class VerbRuntimeCatalog {
  VerbRuntimeCatalog({required Iterable<VerbRuntimeConcept> concepts})
    : conceptsById = Map<VerbConceptId, VerbRuntimeConcept>.unmodifiable(
        _indexRuntimeConcepts(concepts),
      );

  final Map<VerbConceptId, VerbRuntimeConcept> conceptsById;

  List<VerbRuntimeConcept> get concepts {
    return conceptsById.values.toList(growable: false);
  }

  VerbRuntimeConcept? operator [](VerbConceptId id) => conceptsById[id];
}

class VerbRuntimeConcept {
  VerbRuntimeConcept({
    required this.concept,
    required Map<String, Map<String, List<VerbRuntimeExample>>>
    examplesByTenseAndRole,
  }) : examplesByTenseAndRole = _unmodifiableRuntimeExamples(
         examplesByTenseAndRole,
       );

  final VerbConcept concept;
  final Map<String, Map<String, List<VerbRuntimeExample>>>
  examplesByTenseAndRole;

  VerbConceptId get id => concept.id;

  Iterable<VerbRuntimeExample> get examples {
    return examplesByTenseAndRole.values.expand(
      (examplesByRole) => examplesByRole.values.expand((items) => items),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'entryId': id.value,
      'examples': <String, Object?>{
        for (final tenseEntry in examplesByTenseAndRole.entries)
          tenseEntry.key: <String, Object?>{
            for (final roleEntry in tenseEntry.value.entries)
              roleEntry.key: <Object?>[
                for (final example in roleEntry.value) example.toJson(),
              ],
          },
      },
    };
  }
}

class VerbRuntimeExample {
  VerbRuntimeExample({
    required this.conceptId,
    required this.tenseId,
    required this.role,
    required Map<String, String> formGroup,
    required Map<String, String> text,
  }) : formGroup = Map<String, String>.unmodifiable(formGroup),
       text = Map<String, String>.unmodifiable(text);

  final VerbConceptId conceptId;
  final String tenseId;
  final String role;
  final Map<String, String> formGroup;
  final Map<String, String> text;

  Map<String, Object?> toJson() {
    return <String, Object?>{...text};
  }
}

class VerbRoleIds {
  const VerbRoleIds._();

  static const String firstPersonSingular = 'I';
  static const String you = 'You';
  static const String he = 'He';
  static const String she = 'She';
  static const String it = 'It';
  static const String we = 'We';
  static const String youPlural = 'YouPlural';
  static const String youFormal = 'YouFormal';
  static const String youPluralFormal = 'YouPluralFormal';
  static const String they = 'They';

  static const Set<String> all = <String>{
    firstPersonSingular,
    you,
    he,
    she,
    it,
    we,
    youPlural,
    youFormal,
    youPluralFormal,
    they,
  };
}

class VerbTenseIds {
  const VerbTenseIds._();

  static const String presentIndicative = 'presentIndicative';
  static const String presentPerfect = 'presentPerfect';
  static const String preterite = 'preterite';
  static const String imperfectIndicative = 'imperfectIndicative';
  static const String futureSimple = 'futureSimple';
  static const String conditionalSimple = 'conditionalSimple';
  static const String presentSubjunctive = 'presentSubjunctive';
  static const String imperfectSubjunctive = 'imperfectSubjunctive';

  static const Set<String> all = <String>{
    presentIndicative,
    presentPerfect,
    preterite,
    imperfectIndicative,
    futureSimple,
    conditionalSimple,
    presentSubjunctive,
    imperfectSubjunctive,
  };
}

class VerbFormGroupIds {
  const VerbFormGroupIds._();

  static const String firstSingular = 'firstSingular';
  static const String secondSingular = 'secondSingular';
  static const String thirdSingular = 'thirdSingular';
  static const String firstPlural = 'firstPlural';
  static const String secondPlural = 'secondPlural';
  static const String thirdPlural = 'thirdPlural';

  static const Set<String> spanish = <String>{
    firstSingular,
    secondSingular,
    thirdSingular,
    firstPlural,
    secondPlural,
    thirdPlural,
  };
}

String _validateConceptId(String value) {
  final trimmed = value.trim();
  final isValid = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$').hasMatch(trimmed);
  if (!isValid) {
    throw ArgumentError.value(value, 'value', 'Expected snake_case concept id');
  }
  return trimmed;
}

Map<String, List<T>> _unmodifiableStringListMap<T>(Map<String, List<T>> value) {
  return Map<String, List<T>>.unmodifiable(<String, List<T>>{
    for (final entry in value.entries)
      entry.key: List<T>.unmodifiable(entry.value),
  });
}

Map<String, Map<String, String>> _unmodifiableStringMapMap(
  Map<String, Map<String, String>> value,
) {
  return Map<String, Map<String, String>>.unmodifiable(
    <String, Map<String, String>>{
      for (final entry in value.entries)
        entry.key: Map<String, String>.unmodifiable(entry.value),
    },
  );
}

Map<VerbConceptId, VerbRuntimeConcept> _indexRuntimeConcepts(
  Iterable<VerbRuntimeConcept> concepts,
) {
  final indexed = <VerbConceptId, VerbRuntimeConcept>{};
  for (final concept in concepts) {
    final previous = indexed[concept.id];
    if (previous != null) {
      throw ArgumentError.value(
        concept.id.value,
        'concepts',
        'Duplicate concept id',
      );
    }
    indexed[concept.id] = concept;
  }
  return indexed;
}

Map<String, Map<String, List<VerbRuntimeExample>>> _unmodifiableRuntimeExamples(
  Map<String, Map<String, List<VerbRuntimeExample>>> value,
) {
  return Map<String, Map<String, List<VerbRuntimeExample>>>.unmodifiable(
    <String, Map<String, List<VerbRuntimeExample>>>{
      for (final tenseEntry in value.entries)
        tenseEntry.key: Map<String, List<VerbRuntimeExample>>.unmodifiable(
          <String, List<VerbRuntimeExample>>{
            for (final roleEntry in tenseEntry.value.entries)
              roleEntry.key: List<VerbRuntimeExample>.unmodifiable(
                roleEntry.value,
              ),
          },
        ),
    },
  );
}
