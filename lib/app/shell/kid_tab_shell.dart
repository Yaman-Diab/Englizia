import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// Kids mode's three tabs (requirements v3.0 §13.4, design "Kid Media").
enum KidTab { learn, words, me }

/// A kids' tab with its bar: taller, with bigger icons, and no badges.
class KidTabShell extends StatelessWidget {
  const KidTabShell({
    required this.current,
    required this.onSelect,
    required this.child,
    super.key,
  });

  final KidTab current;
  final ValueChanged<KidTab> onSelect;
  final Widget child;

  static const _height = 80.0;
  static const _pillWidth = 68.0;
  static const _pillHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Scaffold(
      backgroundColor: colors.background,
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: _height,
            child: Row(
              children: [
                for (final tab in KidTab.values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: tab == current,
                      label: _label(tab),
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => onSelect(tab),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: AppMotion.resolve(
                                context,
                                AppMotion.quick,
                              ),
                              width: _pillWidth,
                              height: _pillHeight,
                              decoration: BoxDecoration(
                                color: tab == current
                                    ? colors.primary.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  _pillHeight / 2,
                                ),
                              ),
                              child: Icon(
                                _icon(tab),
                                size: AppSizes.iconLg,
                                color: tab == current
                                    ? colors.primary.text
                                    : colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _label(tab),
                              style:
                                  (tab == current
                                          ? texts.bodyStrong
                                          : texts.body)
                                      .copyWith(
                                        color: tab == current
                                            ? colors.primary.text
                                            : colors.textSecondary,
                                        fontSize: 15,
                                        height: 20 / 15,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(KidTab tab) => switch (tab) {
    KidTab.learn => 'tab_learn'.tr(),
    KidTab.words => 'kid_words_title'.tr(),
    KidTab.me => 'tab_me'.tr(),
  };

  static IconData _icon(KidTab tab) => switch (tab) {
    KidTab.learn => Icons.menu_book_rounded,
    KidTab.words => Icons.style_outlined,
    KidTab.me => Icons.person_outline_rounded,
  };
}
