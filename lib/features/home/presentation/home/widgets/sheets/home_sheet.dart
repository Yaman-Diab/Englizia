import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/color_mix.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:flutter/material.dart';

/// Home's own sheets: 24 corners, a 40×4 handle, 12 20 20
/// around and 14 between the parts. They move as every sheet does.
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

/// A home sheet's main action: 52 high with round
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
