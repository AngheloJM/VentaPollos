import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta cálida (naranja/dorado) inspirada en pollo a la brasa.
class AppTheme {
  static const Color primario = Color(0xFFE65100);
  static const Color secundario = Color(0xFFFFB300);
  static const Color fondo = Color(0xFFFFF8F1);

  static ThemeData claro() {
    final esquema = ColorScheme.fromSeed(
      seedColor: primario,
      primary: primario,
      secondary: secundario,
      surface: fondo,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: esquema);
    final texto = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: texto,
      scaffoldBackgroundColor: fondo,
      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: texto.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: esquema.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: texto.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: esquema.primaryContainer,
      ),
    );
  }
}
