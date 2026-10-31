import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:flutter/material.dart';

/// «ما المشكلة؟» over the feedback sheet (S §18): one reason, then send. Null
/// when dismissed, as the scrim sends nothing.
Future<ProblemReason?> showReportSheet(BuildContext context) =>
    showModalBottomSheet<ProblemReason>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: sheetAnimation(context),
      builder: (_) => const _ReportSheet(),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ProblemReason? _reason;

  static const _rowHeight = 52.0;

  static String _label(ProblemReason reason) => switch (reason) {
    ProblemReason.alsoRight => 'lesson_report_also_right'.tr(),
    ProblemReason.audio => 'lesson_report_audio'.tr(),
    ProblemReason.question => 'lesson_report_question'.tr(),
    ProblemReason.translation => 'lesson_report_translation'.tr(),
    ProblemReason.other => 'lesson_report_other'.tr(),
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.lg,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('lesson_report_title'.tr(), style: context.texts.title),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final reason in ProblemReason.values) ...[
          PressScale(
            child: ChoiceSurface(
              selected: _reason == reason,
              radius: AppRadius.md,
              onTap: () => setState(() => _reason = reason),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _rowHeight),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      ChoiceRadio(selected: _reason == reason),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _label(reason),
                          style: context.texts.body.copyWith(
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'lesson_report_send'.tr(),
          size: AppButtonSize.large,
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop(_reason),
        ),
      ],
    ),
  );
}
