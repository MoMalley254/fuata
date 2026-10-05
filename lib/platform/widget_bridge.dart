// ---------------------------------------------------------------------------
// Pushing the widget's snapshot to native (issue #29). One-way: the
// widget provider reads what this wrote and never talks back. A no-op
// when there's no native side (widget tests, non-Android), so callers
// don't have to guard.
// ---------------------------------------------------------------------------

import 'package:flutter/services.dart';

import '../data/constants/method_channels_constants.dart';
import '../domain/logic/widget_content.dart';

abstract class HomeWidgetBridge {
  Future<void> push(WidgetSnapshot snapshot);

  /// Clears the cached snapshot; the widget falls back to its
  /// "open Fuata" empty state on next render. Used when the app is
  /// erased or the person asks to hide the widget's numbers.
  Future<void> clear();
}

class AndroidHomeWidgetBridge implements HomeWidgetBridge {
  AndroidHomeWidgetBridge()
      : _channel = const MethodChannel(homeWidgetMethodName);
  final MethodChannel _channel;

  @override
  Future<void> push(WidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>('update', snapshot.toJson());
    } on MissingPluginException {
      // Widget tests / non-Android: no native side.
    } on PlatformException {
      // A widget that fails to update is not the app's problem; the
      // next push or the launcher's own 30-minute refresh will retry.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // no native side
    } on PlatformException {
      // as above
    }
  }
}