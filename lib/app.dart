import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_settings.dart';
import 'widgets/animated_splash.dart';

class ApniGariApp extends StatelessWidget {
  const ApniGariApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkMode = context.watch<ThemeSettings>().darkMode;
    const navy = Color(0xFF0B1F33);
    const teal = Color(0xFF087E8B);
    const accent = Color(0xFFFFB703);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
      ),
    );
    return MaterialApp(
      title: 'Apni Gari',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: base.colorScheme.copyWith(
          primary: teal,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: navy,
          error: const Color(0xFFBD2C2C),
          surface: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: base.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: const Color(0x120B1F33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE5EBF0)),
          ),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: base.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: base.colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: base.colorScheme.primary, width: 1.4),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: base.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          height: 74,
          indicatorColor: const Color(0xFFE0F4F4),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return base.textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            );
          }),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF35C878),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF35C878),
          onPrimary: const Color(0xFF07140C),
          secondary: const Color(0xFFD9B66F),
          onSecondary: const Color(0xFF211A0D),
          surface: const Color(0xFF111416),
          onSurface: const Color(0xFFF1F3F2),
          surfaceContainerLowest: const Color(0xFF0D1011),
          surfaceContainerLow: const Color(0xFF171B1D),
          surfaceContainer: const Color(0xFF1C2123),
          surfaceContainerHigh: const Color(0xFF242A2C),
          surfaceContainerHighest: const Color(0xFF2B3234),
          outline: const Color(0xFF687376),
          outlineVariant: const Color(0xFF384144),
          primaryContainer: const Color(0xFF1C3A2B),
          onPrimaryContainer: const Color(0xFFC8F4D7),
          secondaryContainer: const Color(0xFF3A3020),
          onSecondaryContainer: const Color(0xFFF2E4C8),
        ),
        scaffoldBackgroundColor: const Color(0xFF111416),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF171B1D),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1C2123),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF30383A)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF202628),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF384144)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF384144)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF35C878), width: 1.5),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF171B1D),
          indicatorColor: const Color(0xFF1C3A2B),
          height: 74,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
              color: selected
                  ? const Color(0xFF35C878)
                  : const Color(0xFFAAB2B4),
            );
          }),
        ),
        dividerColor: const Color(0xFF30383A),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2B3234),
          contentTextStyle: TextStyle(color: Color(0xFFF1F3F2)),
        ),
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AnimatedSplash(),
    );
  }
}
