import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/onboarding/presentation/welcome/widgets/app_name_badge.dart';
import 'package:englizia/features/onboarding/presentation/widgets/staggered_entrance.dart';
import 'package:flutter/material.dart';

/// First screen for anyone without an account (requirements v3.0 §4.2):
/// the guide, the promise, "Start" into onboarding and "I already have an
/// account" into sign-in. Navigation is the router's job, passed in.
class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.onStart, required this.onSignIn, super.key});

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  /// Design sizes: the stage circle and the guide inside it.
  static const _stageDiameter = 248.0;
  static const _mascotRatio = 180 / 248;

  /// The stage gives up height first on short screens.
  static const _stageShareOfHeight = .4;

  /// Text measure from the design, so lines break the same way.
  static const _titleMaxWidth = 296.0;
  static const _bodyMaxWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;

    return Scaffold(
      body: SafeArea(
        child: StaggeredEntrance(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stage = (constraints.maxHeight * _stageShareOfHeight)
                        .clamp(0.0, _stageDiameter);
                    final width = math.min(
                      constraints.maxWidth - AppSpacing.xl * 2,
                      _titleMaxWidth,
                    );
                    // The width is fixed outside IntrinsicHeight so text is
                    // measured at the width it is laid out with.
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: width,
                            child: IntrinsicHeight(
                              child: Column(
                                children: [
                                  const SizedBox(height: AppSpacing.xl),
                                  const EntranceItem(
                                    motion: EntranceMotion.down,
                                    begin: .12,
                                    end: .6,
                                    child: AppNameBadge(),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  const Spacer(),
                                  EntranceItem(
                                    motion: EntranceMotion.pop,
                                    begin: .22,
                                    end: .82,
                                    child: MascotStage(
                                      diameter: stage,
                                      child: Mascot(
                                        size: stage * _mascotRatio,
                                        waving: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  EntranceItem(
                                    motion: EntranceMotion.up,
                                    begin: .34,
                                    end: .82,
                                    child: Text(
                                      'welcome_title'.tr(),
                                      textAlign: TextAlign.center,
                                      style: texts.display,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  EntranceItem(
                                    motion: EntranceMotion.up,
                                    begin: .42,
                                    end: .9,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: math.max(
                                          0,
                                          (width - _bodyMaxWidth) / 2,
                                        ),
                                      ),
                                      child: Text(
                                        'welcome_body'.tr(),
                                        textAlign: TextAlign.center,
                                        style: texts.body.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              EntranceItem(
                motion: EntranceMotion.up,
                begin: .52,
                end: 1,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      AppButton(
                        label: 'welcome_start'.tr(),
                        onPressed: onStart,
                        size: AppButtonSize.large,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'welcome_have_account'.tr(),
                        onPressed: onSignIn,
                        variant: AppButtonVariant.text,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
