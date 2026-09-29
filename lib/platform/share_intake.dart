import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fuata/data/constants/method_channels_constants.dart';

final _channel = MethodChannel(shareIntakeMethodName);
final _sharedText = StreamController<String>.broadcast();
final _queue = <String>[];

/// Text that arrived before anyone was listening (cold start from the
/// share sheet). Drained once by RootShell's initState.
String? _pendingInitialText;

Stream<String> get sharedTextStream => _sharedText.stream;

Future<void> initShareIntake() async {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'onSharedText') {
      _add(call.arguments);
    }
    return null;
  });
  try {
    final initial = await _channel.invokeMethod<dynamic>('getSharedText');
    if (initial is String && initial.trim().isNotEmpty) {
      // No listener yet — stash it; RootShell will drain it in initState.
      _pendingInitialText = initial.trim();
    }
  } on PlatformException {
    // Older builds / widget tests have no native side.
  }
}

/// Returns and clears text stashed before listeners attached.
String? consumePendingSharedText() {
  final t = _pendingInitialText;
  _pendingInitialText = null;
  return t;
}

void _add(dynamic text) {
  if (text is! String) return;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;
  if (!_sharedText.hasListener) {
    _queue.add(trimmed);
    return;
  }
  _sharedText.add(trimmed);
}

/// Called by RootShell after it subscribes — replays anything that
/// arrived before the UI was ready.
List<String> drainShareQueue() {
  final out = List<String>.from(_queue);
  _queue.clear();
  return out;
}
