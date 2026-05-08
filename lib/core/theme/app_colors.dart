import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0E0814);
  static const Color surface = Color(0xFF1A1025);

  // ── Electric Violet brand ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF7B2FFF);
  static const Color accent = Color(0xFFBF8BFF);
  static const Color light = Color(0xFFF4EEFF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF4EEFF);
  static const Color textSecondary = Color(0xFF8C8697);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF4D6A);
  static const Color success = Color(0xFF00E676);

  // ── Chat tick colours ─────────────────────────────────────────────────────
  /// Double-tick when the other person has read — Electric Violet
  static const Color tickRead = primary;

  /// Single/double tick before the message is read — muted grey
  static const Color tickUnread = Color(0xFF6B6479);
}
