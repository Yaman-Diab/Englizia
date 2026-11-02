import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:flutter/material.dart';

final class SheetOption<T> {
  const SheetOption({required this.value, required this.label, this.detail});

  final T value;
  final String label;
  final String? detail;
}

/// One choice among a few, marked three ways: heavier, tinted and with a check.
/// Null when the learner leaves it.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<SheetOption<T>> options,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  sheetAnimationStyle: sheetAnimation(context),
  builder: (_) =>
      _OptionSheet<T>(title: title, selected: selected, options: options),
);

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.selected,
    required this.options,
  });

  final String title;
  final T selected;
  final List<SheetOption<T>> options;

  static const _rowHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: texts.title.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
            for (final option in options)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: option.value == selected,
                child: Material(
                  color: option.value == selected
                      ? colors.primary.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => Navigator.of(context).pop(option.value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _rowHeight),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style:
                                        (option.value == selected
                                                ? texts.bodyStrong
                                                : texts.body)
                                            .copyWith(
                                              color: colors.textPrimary,
                                            ),
                                  ),
                                  if (option.detail case final detail?)
                                    Text(
                                      detail,
                                      style: texts.caption.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (option.value == selected)
                              AppIconView(
                                AppIcon.check,
                                size: AppSizes.iconMd,
                                color: colors.primary.fill,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
