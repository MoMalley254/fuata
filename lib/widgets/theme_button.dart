import 'package:flutter/material.dart';

//TODO: Will be handled via Riverpod later

class ThemeButton extends StatefulWidget {
  const ThemeButton({super.key});

  @override
  State<ThemeButton> createState() => _ThemeButtonState();
}

class _ThemeButtonState extends State<ThemeButton> {
  ThemeMode mode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: toggleTheme,
      icon: const Icon(Icons.brightness_6_rounded),
    );
  }
}
