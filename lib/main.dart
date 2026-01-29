import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/loading_screen.dart';
import 'services/user_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const AttendanceApp());
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({Key? key}) : super(key: key);

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await UserSettingsService.getThemeMode();
    if (!mounted) return;
    setState(() {
      _themeMode = _mapTheme(mode);
      _loaded = true;
    });
  }

  void toggleTheme(String mode) async {
    await UserSettingsService.saveThemeMode(mode);
    if (!mounted) return;
    setState(() {
      _themeMode = _mapTheme(mode);
    });
  }

  ThemeMode _mapTheme(String mode) {
    switch (mode) {
      case "Dark":
        return ThemeMode.dark;
      case "Light":
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,

      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),

      home: _loaded
          ? LoadingScreen(
        onThemeChanged: toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      )
          : const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}