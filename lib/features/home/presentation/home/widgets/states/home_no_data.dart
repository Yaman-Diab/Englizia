import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:flutter/material.dart';

/// Nothing kept and nothing loaded: no header and no map, the
/// guide over the sea and a retry. No error colours: being offline is not
/// the learner's fault. It fills the stage between the top bar and the tab
/// bar; ASSUMPTION(design): in kids mode too (the bar is the route's
/// shell).
class HomeNoData extends StatelessWidget {
  const HomeNoData({required this.failure, required this.onRetry, super.key});

  final Failure failure;
  final VoidCallback onRetry;

  static const _guide = 128.0;
  static const _gap = AppSpacing.md;
  static const _buttonHeight = 52.0;
  static const _buttonPadding = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final sea = SeaPalette.of(context);
    final heading = switch (failure) {
      NetworkFailure() => 'home_no_data'.tr(),
      _ => failure.localizedMessage,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sea.general, sea.seaBottom(sea.general)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ASSUMPTION(design): the design drops the guide's ground
                  // shadow too, which `Mascot` always draws for now.
                  const ExcludeSemantics(
                    child: Mascot(
                      expression: MascotExpression.understand,
                      size: _guide,
                      sparkles: false,
                    ),
                  ),
                  // The design's gap 12, plus the heading's margin 8.
                  const SizedBox(height: _gap + AppSpacing.sm),
                  Semantics(
                    header: true,
                    child: Text(
                      heading,
                      textAlign: TextAlign.center,
                      style: texts
                          .sized(
                            texts.title,
                            size: 20,
                            line: 28,
                            running: false,
                          )
                          .copyWith(color: colors.textPrimary),
                    ),
                  ),
                  // The gap 12, plus the button's margin 6.
                  const SizedBox(height: _gap + AppSpacing.xs + AppSpacing.xxs),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        AppSizes.minTapTarget,
                        _buttonHeight,
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: _buttonPadding,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('common_retry'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
