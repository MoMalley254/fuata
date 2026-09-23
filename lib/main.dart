import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/screens/home_screen.dart';
import 'package:fuata/ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: Fuata()));
}

class Fuata extends StatefulWidget {
  const Fuata({super.key});

  @override
  State<Fuata> createState() => _FuataState();
}

class _FuataState extends State<Fuata> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: HomeScreen(
        onToggleMode: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

