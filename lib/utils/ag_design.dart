import 'package:flutter/material.dart';

/// Central design tokens for Apni Gari.
/// Use these across all screens so the app looks cohesive and matches the
/// intended design.
class AGDesign {
  AGDesign._();

  // ── Brand colors ──
  static const Color navy = Color(0xFF0B1F33);
  static const Color teal = Color(0xFF087E8B);
  static const Color accent = Color(0xFFFFB703);
  static const Color surfaceBg = Color(0xFFF4F7FA);
  static const Color cardBg = Color(0xFFFFFFFF);

  // ── Typography ──
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: Color(0xFF142B41),
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: Color(0xFF142B41),
  );
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF142B41),
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF345260),
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF1F1E1D),
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFF6B6A68),
  );

  // ── Spacing ──
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  // ── Border radius ──
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  // ── Input decoration ──
  static InputDecoration inputDecoration({
    required BuildContext context,
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool filled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: Colors.red, width: 1),
      ),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    );
  }

  /// A subtle section header used on listing screens.
  static Widget sectionHeader(BuildContext context, String text,
      {String? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AGDesign.xs, AGDesign.lg, AGDesign.xs, AGDesign.sm),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AGDesign.navy,
            ),
          ),
          if (action != null) ...[
            const Spacer(),
            Text(
              action,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: teal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
