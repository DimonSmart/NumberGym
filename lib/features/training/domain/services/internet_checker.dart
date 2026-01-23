import 'dart:io';

const Duration _defaultInternetTimeout = Duration(seconds: 2);
const String _defaultInternetHost = 'example.com';

Future<bool> hasInternet({
  Duration timeout = _defaultInternetTimeout,
  String host = _defaultInternetHost,
}) async {
  try {
    final result = await InternetAddress.lookup(host).timeout(timeout);
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
