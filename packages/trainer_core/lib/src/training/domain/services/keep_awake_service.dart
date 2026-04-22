import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

abstract class KeepAwakeServiceBase {
  Future<void> setEnabled(bool enabled);
  void dispose();
}

class KeepAwakeService implements KeepAwakeServiceBase {
  bool _enabled = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
  }
}
