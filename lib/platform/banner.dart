// ---------------------------------------------------------------------------
// The ongoing status banner (issue #16, US-05, ADR-008).
//
// One notification, one fixed id: every change to the person's money
// updates the same notification rather than stacking a new one per
// event. ADR-008 chose a plain ongoing notification over a foreground
// service — Android starts the capture listener itself, and a foreground
// service just to display a number would be both overkill and
// increasingly restricted on newer Android.
//
// Android ties an app's notification colour to its icon, so status is
// shown with the emoji, a progress bar and the accent-tinted small icon
// — never colour alone (ui-design-brief.md 7.10, requirements.md a11y).
//
// US-06's alerts live on a *separate* Android channel (issue #16 lists
// "separate alert channel"), so muting the banner never silences a
// real nudge.
//
// Nothing in this file logs amounts.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/logic/alert_engine.dart';
import '../domain/logic/banner_content.dart';
import '../domain/logic/capture_notification_content.dart';
import '../domain/models/category.dart';
import '../domain/models/limit_alert.dart';
import '../domain/models/limit_rule.dart';
// Circular on purpose: init() registers the top-level background handler
// that lives there, and that file posts through BannerPlatform. Dart allows
// import cycles; the handler has to be named here so every isolate that
// initialises the plugin re-registers it.
import 'capture_notification_actions.dart';

/// What the person did with the banner: opened it, or hit + Add (US-07).
enum BannerAction { open, quickAdd }

/// What the person did on a *capture* notification that needs the app:
/// tapped its body, pressed Fix, or pressed Update balance. Accept and
/// Discard never need the app — they run in the background isolate (see
/// capture_notification_actions.dart) and never reach this type.
enum CaptureTapKind { open, fix, updateBalance }

class CaptureNotificationTap {
  final CaptureTapKind kind;
  final String transactionId;
  const CaptureNotificationTap(this.kind, this.transactionId);

  static const _payloadPrefix = 'capture:';

  static String payloadFor(String transactionId) =>
      '$_payloadPrefix$transactionId';

  /// The transaction id inside a capture notification's payload, or null for
  /// a payload that isn't one (the banner and alerts carry none).
  static String? transactionIdFrom(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    final id = payload.substring(_payloadPrefix.length);
    return id.isEmpty ? null : id;
  }

  /// Null for anything that isn't a capture notification, and for Accept /
  /// Discard (handled without the app).
  static CaptureNotificationTap? fromResponse(NotificationResponse response) {
    final id = transactionIdFrom(response.payload);
    if (id == null) return null;
    return switch (response.actionId) {
      BannerPlatform.captureFixAction => CaptureNotificationTap(
        CaptureTapKind.fix,
        id,
      ),
      BannerPlatform.captureBalanceAction => CaptureNotificationTap(
        CaptureTapKind.updateBalance,
        id,
      ),
      _ when BannerPlatform.isBackgroundCaptureAction(response.actionId) =>
        null,
      _ => CaptureNotificationTap(CaptureTapKind.open, id),
    };
  }
}

class BannerPlatform {
  BannerPlatform._();
  static final instance = BannerPlatform._();

  /// Fixed id: the banner is one ongoing notification, updated in place.
  static const bannerId = 1001;

  /// Ongoing status banner. Default importance, not low: MIUI hides a
  /// low-importance channel from the lock screen entirely (design.md
  /// 5.3), and Android locks a channel's importance after creation. The
  /// silence that `Importance.low` used to buy comes from
  /// `onlyAlertOnce` + `playSound: false` + `enableVibration: false` in
  /// `_androidDetails()` instead, which don't affect lock-screen display.
  static const bannerChannelId = 'fuata_banner';
  static const bannerChannelName = 'Status banner';
  static const bannerChannelDescription =
      'The ongoing banner showing how today is going.';

  /// Separate alert channel (issue #16, US-06). Created here so both are
  /// visible in Android's per-app notification settings before either
  /// has ever been posted to.
  static const alertChannelId = 'fuata_alerts';
  static const alertChannelName = 'Limit alerts';
  static const alertChannelDescription =
      'Nudges when you approach or pass a limit.';

  /// Same alerts, delivered during quiet hours (issue #63). Android fixes
  /// a channel's sound and importance when it is created and ignores
  /// per-notification overrides, so "arrive without a buzz" needs its own
  /// low-importance channel rather than a flag on the loud one.
  static const quietAlertChannelId = 'fuata_alerts_quiet';
  static const quietAlertChannelName = 'Limit alerts (quiet hours)';
  static const quietAlertChannelDescription =
      'Limit alerts that arrive during your quiet hours, without sound.';

  /// Issue #31: scheduled summary notifications. Default importance so
  /// they show on the lock screen (design.md 5.3 — MIUI hides LOW
  /// channels entirely), but the person only sees them if they turned the
  /// feature on.
  static const summaryChannelId = 'fuata_summary';
  static const summaryChannelName = 'Summary notifications';
  static const summaryChannelDescription =
      'Daily, weekly and monthly reminders of how your money went.';

  /// Caught-payment notifications: the one with Accept / Fix / Discard
  /// buttons. High importance so it heads-up — the whole point is acting on
  /// it from wherever the person is. Its own channel, so it can be muted in
  /// Android's settings without touching the banner or the limit alerts.
  static const captureChannelId = 'fuata_captures';
  static const captureChannelName = 'Caught payments';
  static const captureChannelDescription =
      'A payment Fuata caught, with buttons to accept, fix or discard it.';

  /// The same notifications during quiet hours: they still arrive, without
  /// sound or a heads-up. A separate channel for the same reason as
  /// [quietAlertChannelId].
  static const quietCaptureChannelId = 'fuata_captures_quiet';
  static const quietCaptureChannelName = 'Caught payments (quiet hours)';
  static const quietCaptureChannelDescription =
      'Caught payments that arrive during your quiet hours, without sound.';

  /// Action ids on a capture notification. Accept and Discard run in the
  /// background; Fix and Update balance bring the app up.
  static const captureAcceptAction = 'capture_accept';
  static const captureFixAction = 'capture_fix';
  static const captureDiscardAction = 'capture_discard';
  static const captureBalanceAction = 'capture_balance';

  /// Issue #152: note and category from the notification itself. All three
  /// run in the background. "Add details" swaps the buttons to Note /
  /// Category / Fix; Note is an inline reply field; Category swaps them to
  /// the person's most-used categories, and pressing one of those (its id is
  /// [captureSetCategoryPrefix] + the category id) saves it.
  static const captureDetailsAction = 'capture_details';
  static const captureNoteAction = 'capture_note';
  static const captureCategoryAction = 'capture_category';
  static const captureSetCategoryPrefix = 'capture_setcat:';

  /// Presses handled in the background isolate: they never open the app and
  /// must never be mistaken for a body tap.
  static bool isBackgroundCaptureAction(String? actionId) =>
      actionId == captureAcceptAction ||
      actionId == captureDiscardAction ||
      actionId == captureDetailsAction ||
      actionId == captureNoteAction ||
      actionId == captureCategoryAction ||
      (actionId?.startsWith(captureSetCategoryPrefix) ?? false);

  /// The category id inside a category button's action id, else null.
  static String? categoryIdFromAction(String? actionId) {
    if (actionId == null || !actionId.startsWith(captureSetCategoryPrefix)) {
      return null;
    }
    final id = actionId.substring(captureSetCategoryPrefix.length);
    return id.isEmpty ? null : id;
  }

  final _plugin = FlutterLocalNotificationsPlugin();
  final _actions = StreamController<BannerAction>.broadcast();
  final _captureTaps = StreamController<CaptureNotificationTap>.broadcast();
  CaptureNotificationTap? _pendingCaptureTap;
  bool _initialised = false;
  bool _permissionAsked = false;

  /// Taps and + Add presses on the banner. Broadcast — safe to listen
  /// late, safe to have no listener at all.
  Stream<BannerAction> get actions => _actions.stream;

  /// Idempotent. The UI isolate and the listener's background isolate
  /// each call this once on their own plugin instance; Android sees the
  /// same notification id either way.
  Future<void> init() async {
    if (_initialised) return;
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onResponse,
      // Accept / Discard on a capture notification. Registered here, in
      // every isolate that initialises the plugin, so Android can find it
      // even when the UI isn't running.
      onDidReceiveBackgroundNotificationResponse:
          captureNotificationBackgroundHandler,
    );
    await _createChannels();
    _initialised = true;
  }

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        bannerChannelId,
        bannerChannelName,
        description: bannerChannelDescription,
        // Was Importance.low. MIUI (and some other OEMs) treat LOW as
        // "silent" and hide silent notifications from the lock screen
        // entirely, regardless of the notification's own visibility flag.
        // Default importance is the lowest MIUI accepts for lock screen.
        importance: Importance.defaultImportance,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        alertChannelId,
        alertChannelName,
        description: alertChannelDescription,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        quietAlertChannelId,
        quietAlertChannelName,
        description: quietAlertChannelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        captureChannelId,
        captureChannelName,
        description: captureChannelDescription,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        quietCaptureChannelId,
        quietCaptureChannelName,
        description: quietCaptureChannelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        summaryChannelId,
        summaryChannelName,
        description: summaryChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );
  }

  BannerAction? _pending;

  void _onResponse(NotificationResponse response) {
    // A capture notification: Fix / Update balance / a tap on its body.
    // (Accept and Discard are background-only and never arrive here.)
    final captureId = CaptureNotificationTap.transactionIdFrom(
      response.payload,
    );
    if (captureId != null) {
      final tap = CaptureNotificationTap.fromResponse(response);
      if (tap == null) return;
      if (_captureTaps.hasListener) {
        _captureTaps.add(tap);
      } else {
        _pendingCaptureTap = tap; // cold start: Fuata drains it after frame 1
      }
      return;
    }

    final action = response.actionId == 'quick_add'
        ? BannerAction.quickAdd
        : BannerAction.open;
    // Cold start from a banner tap: nobody is listening yet, and a
    // broadcast stream drops un-listened events. Stash it for main.dart
    // to drain after the first frame.
    if (_actions.hasListener) {
      _actions.add(action);
    } else {
      _pending = action;
    }
  }

  /// Fix / Update balance / body taps on capture notifications. Broadcast,
  /// like [actions].
  Stream<CaptureNotificationTap> get captureTaps => _captureTaps.stream;

  /// One-shot read for a cold start: the capture-notification tap that
  /// launched the app, if any. Cleared on read.
  CaptureNotificationTap? consumePendingCaptureTap() {
    final t = _pendingCaptureTap;
    _pendingCaptureTap = null;
    return t;
  }

  /// One-shot read for a cold start: the banner action that launched the
  /// app, if any. Cleared on read.
  BannerAction? consumePendingAction() {
    final a = _pending;
    _pending = null;
    return a;
  }

  /// Post or update the banner. [content] is exactly what the setup
  /// screen's live preview built (BannerContent.build is shared), so the
  /// two can never disagree. [redactOnLockScreen] comes from the
  /// person's `redactedLockScreenBanner` setting.
  Future<void> show(
    BannerContent content, {
    required bool redactOnLockScreen,
  }) async {
    await init();
    await _requestPermissionOnce();
    await _plugin.show(
      id: bannerId,
      title: content.title,
      body: _body(content),
      notificationDetails: NotificationDetails(
        android: _androidDetails(content, redactOnLockScreen),
      ),
    );
  }

  /// Show one limit alert (US-06). Its notification id is derived from the
  /// limit, so a later "almost at your limit" *replaces* the earlier "easy
  /// now" for the same limit instead of stacking beside it. [quiet] posts
  /// it on the silent channel (quiet hours).
  Future<void> showAlert(
    LimitAlert alert, {
    required bool quiet,
    required bool redactOnLockScreen,
  }) async {
    await init();
    await _requestPermissionOnce();
    final text = AlertText.build(alert);
    await _plugin.show(
      id: alertIdFor(alert.limit.id),
      title: text.title,
      body: text.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          quiet ? quietAlertChannelId : alertChannelId,
          quiet ? quietAlertChannelName : alertChannelName,
          channelDescription: quiet
              ? quietAlertChannelDescription
              : alertChannelDescription,
          importance: quiet ? Importance.low : Importance.high,
          priority: quiet ? Priority.low : Priority.high,
          autoCancel: true,
          visibility: redactOnLockScreen
              ? NotificationVisibility.private
              : NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
          color: _statusColor(alert.level.status),
          styleInformation: BigTextStyleInformation(text.body),
        ),
      ),
    );
  }

  /// Post a caught payment with Accept / Fix / Discard buttons (US-09/11).
  /// Its id is derived from the transaction, so a re-post replaces rather
  /// than stacks, and so [cancelCapture] can find it again. [quiet] posts it
  /// on the silent channel (quiet hours).
  ///
  /// [mode] picks the buttons (see [CaptureNotificationMode]); [categoryChoices]
  /// is only read in the categories mode. [update] is for re-posting the same
  /// notification after a button was pressed on it: Android then updates it in
  /// place without buzzing or heads-up-ing a second time.
  Future<void> showCapture(
    CaptureNotificationContent content, {
    required bool quiet,
    required bool redactOnLockScreen,
    CaptureNotificationMode mode = CaptureNotificationMode.main,
    List<Category> categoryChoices = const [],
    bool update = false,
  }) async {
    await init();
    await _requestPermissionOnce();
    await _plugin.show(
      id: captureIdFor(content.transactionId),
      title: content.title,
      body: content.body,
      payload: CaptureNotificationTap.payloadFor(content.transactionId),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          quiet ? quietCaptureChannelId : captureChannelId,
          quiet ? quietCaptureChannelName : captureChannelName,
          channelDescription: quiet
              ? quietCaptureChannelDescription
              : captureChannelDescription,
          importance: quiet ? Importance.low : Importance.high,
          priority: quiet ? Priority.low : Priority.high,
          autoCancel: true,
          visibility: redactOnLockScreen
              ? NotificationVisibility.private
              : NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
          onlyAlertOnce: update,
          styleInformation: BigTextStyleInformation(content.body),
          actions: _captureActions(mode, categoryChoices),
        ),
      ),
    );
  }

  /// Android shows at most three actions on a notification, so each mode is
  /// exactly three or fewer.
  List<AndroidNotificationAction> _captureActions(
    CaptureNotificationMode mode,
    List<Category> categoryChoices,
  ) {
    switch (mode) {
      case CaptureNotificationMode.main:
        return const [
          // Background: no app launch. cancelNotification removes it the
          // moment it is pressed, so a second press can't double-act.
          AndroidNotificationAction(
            captureAcceptAction,
            'Accept',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          // Swaps this notification's buttons in place (it is re-posted by
          // the background handler), so it must not cancel it.
          AndroidNotificationAction(
            captureDetailsAction,
            'Add details',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            captureDiscardAction,
            'Discard',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ];
      case CaptureNotificationMode.details:
        return const [
          // An inline reply field. Not cancelled: Android keeps the
          // notification with a spinner until it is re-posted, which the
          // handler always does (or cancels it, if the row is gone).
          AndroidNotificationAction(
            captureNoteAction,
            'Note',
            showsUserInterface: false,
            cancelNotification: false,
            inputs: [AndroidNotificationActionInput(label: 'Add a note')],
          ),
          AndroidNotificationAction(
            captureCategoryAction,
            'Category',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          // Fixing needs the person's hands, so this one opens the app
          // straight onto the Fix sheet.
          AndroidNotificationAction(
            captureFixAction,
            'Fix',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ];
      case CaptureNotificationMode.categories:
        return [
          for (final c in categoryChoices.take(
            CaptureNotificationText.maxCategoryButtons,
          ))
            AndroidNotificationAction(
              '$captureSetCategoryPrefix${c.id}',
              '${c.emoji} ${c.name}',
              showsUserInterface: false,
              cancelNotification: false,
            ),
        ];
    }
  }

  /// "Added — but the balance looks off", with an Update balance button that
  /// opens the app on that sheet. Same id as the capture it follows, so it
  /// takes that notification's place.
  Future<void> showBalanceMismatch(
    CaptureNotificationContent content, {
    required bool redactOnLockScreen,
  }) async {
    await init();
    await _plugin.show(
      id: captureIdFor(content.transactionId),
      title: content.title,
      body: content.body,
      payload: CaptureNotificationTap.payloadFor(content.transactionId),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          captureChannelId,
          captureChannelName,
          channelDescription: captureChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          visibility: redactOnLockScreen
              ? NotificationVisibility.private
              : NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(content.body),
          actions: const [
            AndroidNotificationAction(
              captureBalanceAction,
              'Update balance',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Removes a capture's notification — used when the person deals with the
  /// capture in the app, so a stale Accept button isn't left in the shade.
  Future<void> cancelCapture(String transactionId) async {
    // Housekeeping after the real work (a confirm, a discard, a fix) has
    // already been saved — it must never be what makes that look like it
    // failed, and it has no plugin to talk to in widget tests.
    try {
      await init();
      await _plugin.cancel(id: captureIdFor(transactionId));
    } catch (_) {}
  }

  /// Same FNV-1a as [alertIdFor], in its own id range (5,000,000 and up) so
  /// the two can never collide with each other, the banner or the summaries.
  static int captureIdFor(String transactionId) {
    var h = 0x811c9dc5;
    for (final unit in transactionId.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return 5000000 + (h % 1000000);
  }

  /// Stable across runs and isolates (String.hashCode is not guaranteed
  /// to be), and clear of [bannerId]. FNV-1a, folded into a positive
  /// 31-bit range above 2000.
  static int alertIdFor(String limitId) {
    var h = 0x811c9dc5;
    for (final unit in limitId.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return 2000 + (h % 1000000);
  }

  Future<void> cancel() async {
    await init();
    await _plugin.cancel(id: bannerId);
  }

  /// Ask once per process (Android 13+). No-op on older Androids and
  /// after the first decision, so it never re-prompts.
  Future<void> _requestPermissionOnce() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
      >();
      await android?.requestNotificationsPermission();
    } catch (e) {
      // No Activity in a background isolate: skip the prompt, the UI isolate asks.
      debugPrint('[banner] permission prompt skipped: ${e.runtimeType}');
    }
  }

  AndroidNotificationDetails _androidDetails(
    BannerContent content,
    bool redactOnLockScreen,
  ) {
    final progress = content.progress;
    final body = _body(content);

    return AndroidNotificationDetails(
      bannerChannelId,
      bannerChannelName,
      channelDescription: bannerChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      // ongoing + autoCancel:false so Android treats it as a status
      // indicator and a tap doesn't silently remove it. On Android 14+
      // a person *can* still dismiss it; the data-driven re-post is what
      // brings it back (design.md ADR-008).
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      showWhen: false,
      category: AndroidNotificationCategory.status,
      // private redacts content on a secure lock screen; public shows
      // everything. The banner is always built unredacted — Android
      // does the redaction, not us, so the shade and the lock screen
      // can differ without keeping two BannerContents.
      visibility: redactOnLockScreen
          ? NotificationVisibility.private
          : NotificationVisibility.public,
      // `icon` is the small-icon resource name in
      // flutter_local_notifications (there is no `smallIcon` parameter).
      icon: '@mipmap/ic_launcher',
      color: _statusColor(content.status),
      showProgress: progress != null,
      maxProgress: 100,
      progress: progress == null ? 0 : (progress * 100).round(),
      actions: [
        if (content.showQuickAdd)
          const AndroidNotificationAction(
            'quick_add',
            '+ Add',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        const AndroidNotificationAction(
          'open',
          'Open',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
      styleInformation: body.isEmpty ? null : BigTextStyleInformation(body),
    );
  }

  /// Expanded body: the unit split, then the spent-today line. Empty
  /// when the content is redacted — the title alone carries the status.
  String _body(BannerContent content) => [
    if (content.unitLines.isNotEmpty) content.unitLines.join(' · '),
    if (content.spentLine != null) content.spentLine!,
  ].join('\n');

  /// Android takes a single ARGB colour, and this isolate has no access
  /// to AppColors — the theme extension isn't available on the platform
  /// side. These are the same hex values AppColors.light ships (see
  /// lib/ui/theme/app_colors.dart); kept explicit here because the
  /// banner is a platform concern, not a themed widget.
  Color _statusColor(SpendStatus status) => switch (status) {
    SpendStatus.safe => const Color(0xFF2E9E6B),
    SpendStatus.warning => const Color(0xFFE8A317),
    SpendStatus.danger => const Color(0xFFE5533D),
    SpendStatus.overdraft => const Color(0xFFB3123F),
  };

  /// Reads the action that *launched a terminated app* — a banner tap or its
  /// + Add pressed while Fuata was not running. The in-process `_onResponse`
  /// callback cannot fire in that case; the plugin records the action in the
  /// launch details instead. Returns null when the app was launched normally.
  Future<BannerAction?> initialActionFromLaunch() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final response = details!.notificationResponse;
    if (response == null) return null;
    // A capture notification launched us: park it for Fuata to act on after
    // the first frame, and leave the router on its normal start location.
    final captureTap = CaptureNotificationTap.fromResponse(response);
    if (captureTap != null) {
      _pendingCaptureTap = captureTap;
      return null;
    }
    return response.actionId == 'quick_add'
        ? BannerAction.quickAdd
        : BannerAction.open;
  }

  /// Ask for notification permission (Android 13+), waiting for the
  /// answer. Unlike [_requestPermissionOnce], this always asks — used from
  /// onboarding's banner step (F15), where the person just said yes and is
  /// looking at the explanation. Returns true when notifications are on
  /// (either just granted, or the OS has no prompt to show).
  Future<bool> requestNotificationPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    _permissionAsked = true;
    return granted ?? true;
  }

  /// Whether Android will actually deliver Fuata's notifications. False
  /// when the person denied the permission (Android 13+) or turned the
  /// app's notifications off in system settings.
  Future<bool> areNotificationsEnabled() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }
}
