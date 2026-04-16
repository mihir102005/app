import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:keepsafe/viewmodels/file_provider.dart';
import 'package:keepsafe/views/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileProvider()),
      ],
      child: const KeepSafeApp(),
    ),
  );
}

class KeepSafeApp extends StatelessWidget {
  const KeepSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keepsafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F172A), // Deep Navy
        scaffoldBackgroundColor: const Color(0xFF020617), // Ebony
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFACC15), // Gold accent
          secondary: Color(0xFF22D3EE), // Cyan accent
          surface: Color(0xFF1E293B), // Slate Slate
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFACC15),
          foregroundColor: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
