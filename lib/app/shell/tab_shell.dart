import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// The app's four tabs (S §6).
enum AppTab { learn, practice, talk, me }

/// A tab's page with the tabs' bar under it; each tab's route builds it
/// around its page (plain routes, D-084).
class TabShell extends StatelessWidget {
  const TabShell({
    required this.current,
    required this.onSelect,
    required this.child,
    this.badges = const {},
    super.key,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final Widget child;

  /// What waits on a tab, as «تدرّب»'s reviews due today.
  final Map<AppTab, int> badges;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: _TabBar(
      current: current,
      badges: badges,
      onSelect: onSelect,
    ),
  );
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.current,
    required this.badges,
    required this.onSelect,
  });

  final AppTab current;
  final Map<AppTab, int> badges;
  final ValueChanged<AppTab> onSelect;

  static const _height = 68.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
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
              for (final tab in AppTab.values)
                Expanded(
                  child: _TabItem(
                    tab: tab,
                    current: tab == current,
                    badge: badges[tab] ?? 0,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.current,
    required this.badge,
    required this.onTap,
  });

  final AppTab tab;
  final bool current;
  final int badge;
  final VoidCallback onTap;

  static const _pillWidth = 56.0;
  static const _pillHeight = 30.0;
  static const _badge = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final (IconData icon, String label) = switch (tab) {
      AppTab.learn => (Icons.menu_book_rounded, 'tab_learn'.tr()),
      AppTab.practice => (Icons.style_outlined, 'tab_practice'.tr()),
      AppTab.talk => (Icons.chat_bubble_outline_rounded, 'tab_talk'.tr()),
      AppTab.me => (Icons.person_outline_rounded, 'tab_me'.tr()),
    };
    // «تحدّث» is the AI's tab, so it is chosen in violet (design "Talk").
    final tone = tab == AppTab.talk ? colors.ai : colors.primary;
    final ink = current
        ? (tab == AppTab.talk ? tone.text : tone.fill)
        : colors.textSecondary;
    return Semantics(
      button: true,
      selected: current,
      label: badge > 0
          ? 'tab_with_badge'.tr(namedArgs: {'tab': label, 'count': '$badge'})
          : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: AppMotion.resolve(context, AppMotion.quick),
                  width: _pillWidth,
                  height: _pillHeight,
                  decoration: BoxDecoration(
                    color: current ? tone.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(_pillHeight / 2),
                  ),
                  child: Icon(icon, size: AppSizes.iconMd, color: ink),
                ),
                if (badge > 0)
                  PositionedDirectional(
                    end: AppSpacing.sm,
                    top: -AppSpacing.xs,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: _badge,
                        minHeight: _badge,
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryStrong,
                        borderRadius: BorderRadius.circular(_badge / 2),
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$badge',
                        style: texts.captionStrong.copyWith(
                          color: colors.onPrimaryStrong,
                          fontSize: texts.caption.fontSize! * .77,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: (current ? texts.captionStrong : texts.caption).copyWith(
                color: ink,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
