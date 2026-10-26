import 'package:flutter/painting.dart';

/// Raw palette (Tailwind scale names). Only `app_semantic_colors.dart` and
/// `app_theme.dart` read it; widgets use roles via `context.colors`.
///
/// Light-mode role colors follow the identity docs in docs/product/:
/// proposal 1.0 (primary, status fills, success/error surfaces, neutrals) and
/// v2, which keeps 1.0 unless it says otherwise (reader, captions, reward dark).
/// Dark neutrals, primary text, error and success come from the token table in
/// the approved designs (Claude Design, "Create Account v3"), which requirements
/// v3.0 §22 makes the reference until the identity token block is completed.
// ASSUMPTION(design): light text tokens, the remaining status surfaces and the
// other dark values have no value in the docs or that table — provisional.
abstract final class AppPalette {
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue300 = Color(0xFF93C5FD);
  static const blue400 = Color(0xFF60A5FA);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue900 = Color(0xFF1E3A8A);
  static const blue950 = Color(0xFF172554);

  static const green100 = Color(0xFFDCFCE7);
  static const green300 = Color(0xFF86EFAC);
  static const green400 = Color(0xFF4ADE80);
  static const green500 = Color(0xFF22C55E);
  static const green700 = Color(0xFF15803D);
  static const green900 = Color(0xFF14532D);

  static const orange100 = Color(0xFFFFEDD5);
  static const orange300 = Color(0xFFFDBA74);
  static const orange400 = Color(0xFFFB923C);
  static const orange500 = Color(0xFFF97316);
  static const orange700 = Color(0xFFC2410C);
  static const orange900 = Color(0xFF7C2D12);

  static const amber100 = Color(0xFFFEF3C7);
  static const amber300 = Color(0xFFFCD34D);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber700 = Color(0xFFB45309);
  static const amber900 = Color(0xFF78350F);

  static const violet100 = Color(0xFFEDE9FE);
  static const violet300 = Color(0xFFC4B5FD);
  static const violet400 = Color(0xFFA78BFA);
  static const violet500 = Color(0xFF8B5CF6);
  static const violet700 = Color(0xFF6D28D9);
  static const violet900 = Color(0xFF4C1D95);

  static const red100 = Color(0xFFFEE2E2);
  static const red300 = Color(0xFFFCA5A5);
  static const red400 = Color(0xFFF87171);
  static const red500 = Color(0xFFEF4444);
  static const red700 = Color(0xFFB91C1C);
  static const red900 = Color(0xFF7F1D1D);

  static const cyan100 = Color(0xFFCFFAFE);
  static const cyan300 = Color(0xFF67E8F9);
  static const cyan400 = Color(0xFF22D3EE);
  static const cyan500 = Color(0xFF06B6D4);
  static const cyan700 = Color(0xFF0E7490);
  static const cyan900 = Color(0xFF164E63);

  static const yellow300 = Color(0xFFFDE047);

  // Dark column of the designs' token table.
  static const night950 = Color(0xFF0C1220);
  static const night900 = Color(0xFF131C2E);
  static const night500 = Color(0xFF5F6E8A);
  static const night300 = Color(0xFFA9B5C8);
  static const night100 = Color(0xFFE8EEF8);
  static const sky300 = Color(0xFF8AB4FF);
  static const coral950 = Color(0xFF3A1A18);
  static const coral400 = Color(0xFFF28B82);
  static const coral200 = Color(0xFFF2B8B5);
  static const mint400 = Color(0xFF5FD394);
  static const mint300 = Color(0xFF8BE0B0);

  /// Caption background over video: black at 60%.
  static const captionScrim = Color(0x99000000);
}
