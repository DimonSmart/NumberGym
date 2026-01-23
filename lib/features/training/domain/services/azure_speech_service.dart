import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../pronunciation_models.dart';

class AzureSpeechService {
  AzureSpeechService({http.Client? client, Uri? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? Uri.parse(_defaultEndpoint);

  final http.Client _client;
  final Uri _endpoint;

  static const String _defaultEndpoint =
      'https://numbergym-api-173517264.azurewebsites.net/api/pronunciation/analyze';

  Future<PronunciationAnalysisResult> analyzePronunciation({
    required File audioFile,
    required String expectedText,
    required String language,
  }) async {
    final request = http.MultipartRequest('POST', _endpoint)
      ..fields['expectedText'] = expectedText
      ..fields['language'] = language;

    request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AzureSpeechFailure(
        'Request failed',
        statusCode: response.statusCode,
        body: body,
      );
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return PronunciationAnalysisResult.fromJson(decoded);
  }
}
