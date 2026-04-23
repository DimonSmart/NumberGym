import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:number_gym/features/training/domain/services/azure_speech_service.dart';

import 'helpers/training_fakes.dart';

void main() {
  test('dispose closes azure speech client', () {
    final client = _TrackingClient();
    final services = buildFakeTrainingServices(
      azure: AzureSpeechService(
        client: client,
        endpoint: Uri.parse('http://localhost:1/pronunciation/analyze'),
      ),
    );

    services.dispose();

    expect(client.closed, isTrue);
  });
}

class _TrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  void close() {
    closed = true;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError('Not used in this test.');
  }
}
