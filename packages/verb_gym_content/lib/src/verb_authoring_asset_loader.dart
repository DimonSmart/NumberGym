import 'dart:convert';

import 'package:flutter/services.dart';

import 'verb_authoring_loader.dart';
import 'verb_authoring_models.dart';

const String defaultVerbAuthoringAssetRoot =
    'packages/verb_gym_content/assets/authoring';

class VerbAuthoringAssetLoader {
  VerbAuthoringAssetLoader({
    AssetBundle? bundle,
    this.assetRoot = defaultVerbAuthoringAssetRoot,
  }) : bundle = bundle ?? rootBundle;

  final AssetBundle bundle;
  final String assetRoot;

  Future<VerbRuntimeCatalog> loadRuntimeCatalog() async {
    final indexSource = await bundle.loadString('$assetRoot/index.json');
    final fileNames = _readIndex(indexSource);
    final sources = <String>[];

    for (final fileName in fileNames) {
      sources.add(await bundle.loadString('$assetRoot/$fileName'));
    }

    return const VerbAuthoringLoader().loadRuntimeCatalogFromJsonStrings(
      sources,
    );
  }

  List<String> _readIndex(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Verb authoring index must be a list');
    }

    final fileNames = <String>[];
    final seen = <String>{};
    for (var index = 0; index < decoded.length; index += 1) {
      final value = decoded[index];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Verb authoring index[$index] must be a string');
      }
      if (!value.endsWith('.json') ||
          value.contains('/') ||
          value.contains('\\')) {
        throw FormatException(
          'Verb authoring index[$index] must be a JSON file name',
        );
      }
      if (!seen.add(value)) {
        throw FormatException(
          'Verb authoring index contains duplicate file "$value"',
        );
      }
      fileNames.add(value);
    }

    if (fileNames.isEmpty) {
      throw const FormatException('Verb authoring index must not be empty');
    }
    return fileNames;
  }
}
