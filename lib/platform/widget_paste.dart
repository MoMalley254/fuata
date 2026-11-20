// ---------------------------------------------------------------------------
// The widget paste activity's channel (issue #153). Only ever talked to from
// the widget-paste Flutter engine started by WidgetPasteActivity.kt.
// ---------------------------------------------------------------------------

import 'package:flutter/services.dart';

import '../data/constants/method_channels_constants.dart';

class WidgetPasteChannel {
  WidgetPasteChannel._();
  static const _channel = MethodChannel(widgetPasteMethodName);

  /// The clipboard text, trimmed; null when it is empty or not text.
  /// Native reads it once the window has focus (Android 10+ rule), so this
  /// may wait a few milliseconds.
  static Future<String?> readClipboard() async {
    try {
      return await _channel.invokeMethod<String>('getClipboard');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Milliseconds since the activity's onCreate. Timing aid only (#153
  /// follow-up 6.1); null if the native side doesn't answer.
  static Future<int?> msSinceCreate() async {
    try {
      return await _channel.invokeMethod<int>('msSinceCreate');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Closes the paste window, optionally with a toast ("Added KSh 500...").
  static Future<void> finish({String? message}) async {
    try {
      await _channel.invokeMethod<void>('finish', {'message': message});
    } on MissingPluginException {
      // no native side
    } on PlatformException {
      // nothing useful to do
    }
  }

  /// Brings the real app up (to create units or teach a format) and closes
  /// the paste window.
  static Future<void> openApp() async {
    try {
      await _channel.invokeMethod<void>('openApp');
    } on MissingPluginException {
      // no native side
    } on PlatformException {
      // nothing useful to do
    }
  }
}
