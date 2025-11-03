import 'package:flutter/material.dart';
import 'core/themes.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RecXiaomiFirmwareMakerApp());
}

class RecXiaomiFirmwareMakerApp extends StatelessWidget {
  const RecXiaomiFirmwareMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecXiaomiFirmwareMaker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
