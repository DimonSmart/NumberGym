class VoicesReady {
  Future<void> wait({Duration timeout = const Duration(seconds: 2)}) async {
    // No-op on non-web platforms.
  }

  void dispose() {}
}
