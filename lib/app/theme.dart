import 'package:flutter/material.dart';

ThemeData ecoTheme() {
  const green = Color(0xFF2E7D32);
  return ThemeData(
    fontFamily: 'Roboto',
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        secondary: const Color(0xFF4CAF50),
        surface: Colors.white),
    scaffoldBackgroundColor: const Color(0xFFF6F9F6),
    appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F9F6), centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)))),
  );
}
