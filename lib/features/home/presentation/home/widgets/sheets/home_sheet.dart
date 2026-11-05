import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/color_mix.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:flutter/material.dart';

/// Home's own sheets (bubble §11): 24 corners, a 40×4 handle, 12 20 20
/// around and 14 between the parts. They move as every sheet does (D33).
Future<T?> showHomeSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(HomeSheet.radius)),
  ),
  sheetAnimationStyle: sheetAnimation(context),
  builder: (sheet) => SingleChildScrollView(
    padding: EdgeInsetsDirectional.fromSTEB(
      HomeSheet.side,
      HomeSheet.top,
      HomeSheet.side,
      HomeSheet.bottom +
          MediaQuery.viewInsetsOf(sheet).bottom +
          MediaQuery.paddingOf(sheet).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        const SizedBox(height: HomeSheet.gap),
        builder(sheet),
      ],
    ),
  ),
);

/// The design's measures for home's sheets.
abstract final class HomeSheet {
  static const radius = 24.0;
  static const side = 20.0;
  static const top = 12.0;
  static const bottom = 20.0;
  static const gap = 14.0;

  /// Arabic running text never goes below the theme's line height.
  static const _arabicMinHeight = 1.7;

  /// [role] at the design's [size] and [line]. Arabic running text keeps
  /// at least the theme's 1.7 (PLAN §5.4); a single line keeps the design's.
  static TextStyle text(
    BuildContext context,
    TextStyle role, {
    required double size,
    required double line,
    bool running = true,
  }) {
    var height = line / size;
    if (running &&
        context.locale.languageCode == AppLocales.arabic.languageCode) {
      height = math.max(height, _arabicMinHeight);
    }
    return role.copyWith(fontSize: size, height: height);
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: context.scheme.outline,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// A home sheet's main action (bubble §8.1, §12.3): 52 high with round
/// ends. Disabled, it keeps its white text on a faded fill.
class HomeSheetButton extends StatelessWidget {
  const HomeSheetButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  static const height = 52.0;

  /// The disabled fill's share of the strong border, over the surface.
  static const _disabledShare = .45;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(height),
        shape: const StadiumBorder(),
        backgroundColor: colors.primaryStrong,
        foregroundColor: colors.onPrimaryStrong,
        disabledBackgroundColor: mixOklch(
          context.scheme.outline,
          colors.surface,
          _disabledShare,
        ),
        disabledForegroundColor: colors.onPrimaryStrong,
        textStyle: context.texts.button.copyWith(height: 1),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
