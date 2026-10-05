import 'package:flutter/material.dart';

/// The root navigator/messenger used by the router and by anything that
/// needs to reach them outside a widget tree (the review inbox's reconcile
/// snackbar, the share-intake listener, the banner action handler).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>(
  debugLabel: 'rootSm',
);
