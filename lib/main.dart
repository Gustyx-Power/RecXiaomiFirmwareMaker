import 'package:flutter/material.dart';
import 'core/themes.dart';
import 'screens/dependency_check_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RecXiaomiFirmwareMakerApp());
}

class RecXiaomiFirmwareMakerApp extends StatefulWidget {
  const RecXiaomiFirmwareMakerApp({super.key});

  @override
  State<RecXiaomiFirmwareMakerApp> createState() => _RecXiaomiFirmwareMakerAppState();
}

class _RecXiaomiFirmwareMakerAppState extends State<RecXiaomiFirmwareMakerApp> {
  bool _dependenciesReady = false;

  void _onDependenciesReady() {
    setState(() {
      _dependenciesReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecXiaomiFirmwareMaker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: _dependenciesReady
          ? const HomeScreen()
          : DependencyCheckScreen(
        onDependenciesReady: _onDependenciesReady,
      ),
    );
  }
}
