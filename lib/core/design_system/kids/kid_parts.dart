import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The kids' corners (design).
const kidRadius = 20.0;

/// A star of the kids' designs: [filled] in the reward color, or an empty one
/// to fill; [outlined] rides on colored ground, as the bar's does.
class KidStar extends StatelessWidget {
  const KidStar({
    required this.size,
    this.filled = true,
    this.outlined = false,
    super.key,
  });

  final double size;
  final bool filled;
  final bool outlined;

  static const _path =
      'M12 2.8l2.75 5.6 6.15.9-4.45 4.35 1.05 6.1L12 16.85 6.5 19.75l1.05-6.1'
      'L3.1 9.3l6.15-.9z';

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = filled ? colors.reward.fill : colors.surface;
    final stroke = outlined
        ? colors.surface
        : filled
        ? colors.reward.fill
        : colors.border;
    final width = outlined ? 2.2 : (filled ? 1.2 : 1.6);
    return ExcludeSemantics(
      child: SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 -1 26 26">'
        '<path d="$_path" fill="${_hex(fill)}" stroke="${_hex(stroke)}" '
        'stroke-width="$width" stroke-linejoin="round"/></svg>',
        width: size,
        height: size,
      ),
    );
  }
}

/// A word's picture: from the server, or a bundled file in mock mode.
class KidPicture extends StatelessWidget {
  const KidPicture({required this.url, required this.size, super.key});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: url.isEmpty
          ? null
          : url.startsWith('http')
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : SvgPicture.asset(url),
    ),
  );
}

/// A round button of the kids' designs, with an icon and no text: [primary]
/// for the step forward, [info] for a sound.
class KidRoundButton extends StatelessWidget {
  const KidRoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 72,
    this.iconSize,
    this.primary = false,
    this.info = false,
    this.ringed = false,
    super.key,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;
  final bool primary;
  final bool info;

  /// A soft ring around it while its sound plays.
  final bool ringed;

  static const _ring = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = primary
        ? colors.primaryStrong
        : info
        ? colors.info.fill
        : colors.surface;
    final ink = primary || info ? colors.surface : colors.primaryStrong;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.closeUp),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: primary || info
                  ? null
                  : Border.all(color: colors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: ringed ? colors.info.surface : Colors.transparent,
                  spreadRadius: _ring,
                ),
              ],
            ),
            child: IconTheme(
              data: IconThemeData(color: ink, size: iconSize ?? size * .47),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

/// A kids' screen's bar: the way out, the progress with a star riding on its
/// end, and the guide, who says the instruction again when pressed.
class KidTopBar extends StatelessWidget {
  const KidTopBar({
    required this.progress,
    required this.total,
    required this.speaking,
    required this.expression,
    required this.starKey,
    required this.onExit,
    required this.onGuide,
    super.key,
  });

  /// The screens done, of [total].
  final int progress;
  final int total;
  final bool speaking;
  final MascotExpression expression;

  /// Where a star flies to.
  final GlobalKey starKey;
  final VoidCallback onExit;
  final VoidCallback onGuide;

  static const _height = 72.0;
  static const _exit = 56.0;
  static const _track = 16.0;
  static const _star = 30.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final share = total == 0 ? 0.0 : progress / total;
    final duration = AppMotion.resolve(context, AppMotion.slow * 1.5);
    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.xs + AppSpacing.xxs,
        ),
        child: Row(
          children: [
            KidRoundButton(
              icon: AppIconView(
                AppIcon.door,
                size: AppSizes.iconLg - AppSpacing.xs,
                color: colors.textSecondary,
              ),
              label: 'kid_exit'.tr(),
              size: _exit,
              onPressed: onExit,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.md + AppSpacing.xxs,
                  end: AppSpacing.md + AppSpacing.xxs,
                ),
                child: Semantics(
                  label: 'kid_progress'.tr(),
                  value: '$progress / $total',
                  child: SizedBox(
                    height: _star,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return Stack(
                          clipBehavior: Clip.none,
                          alignment: AlignmentDirectional.centerStart,
                          children: [
                            Container(
                              height: _track,
                              decoration: BoxDecoration(
                                color: colors.primary.surface,
                                borderRadius: BorderRadius.circular(_track / 2),
                              ),
                            ),
                            AnimatedContainer(
                              duration: duration,
                              curve: AppMotion.smoothOut,
                              width: width * share,
                              height: _track,
                              decoration: BoxDecoration(
                                color: colors.primary.fill,
                                borderRadius: BorderRadius.circular(_track / 2),
                              ),
                            ),
                            AnimatedPositionedDirectional(
                              duration: duration,
                              curve: AppMotion.smoothOut,
                              start: width * share - _star / 2,
                              top: 0,
                              child: Pulse(
                                trigger: progress,
                                growth: .6,
                                child: KidStar(
                                  key: starKey,
                                  size: _star,
                                  outlined: true,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            KidGuideButton(
              speaking: speaking,
              expression: expression,
              onPressed: onGuide,
            ),
          ],
        ),
      ),
    );
  }
}

/// The guide in a corner with its sound bubble, ringed while it speaks;
/// pressed, it says the instruction again.
class KidGuideButton extends StatelessWidget {
  const KidGuideButton({
    required this.speaking,
    required this.expression,
    required this.onPressed,
    this.label,
    super.key,
  });

  final bool speaking;
  final MascotExpression expression;
  final VoidCallback onPressed;

  /// What pressing it says; by default, the instruction again.
  final String? label;

  static const _guide = 64.0;
  static const _bubble = 30.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label ?? 'kid_say_again'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.closeUp),
              margin: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
              width: _bubble,
              height: _bubble,
              decoration: BoxDecoration(
                color: colors.info.surface,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(_bubble / 2),
                  topEnd: Radius.circular(_bubble / 2),
                  bottomStart: Radius.circular(_bubble / 2),
                  bottomEnd: Radius.circular(AppSpacing.xs),
                ),
                boxShadow: [
                  BoxShadow(
                    color: speaking ? colors.info.fill : Colors.transparent,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.volume_up_rounded,
                size: AppSizes.iconSm,
                color: colors.info.fill,
              ),
            ),
            Mascot(expression: expression, size: _guide, sparkles: false),
          ],
        ),
      ),
    );
  }
}

/// «تريد أن تخرج؟» with two pictures and no words: the guide smiling with an
/// arrow to stay, or a little sad with a door to leave. Outside it is staying.
/// True to leave.
Future<bool> showKidExitSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: sheetAnimation(context),
      builder: (_) => const _ExitSheet(),
    ) ??
    false;

class _ExitSheet extends StatelessWidget {
  const _ExitSheet();

  static const _height = 208.0;
  static const _guide = 112.0;
  static const _mark = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget choice({
      required bool leave,
      required MascotExpression expression,
      required Widget mark,
    }) => Expanded(
      child: Semantics(
        button: true,
        label: leave ? 'kid_leave'.tr() : 'kid_stay'.tr(),
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(leave),
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: leave ? colors.surface : colors.primary.surface,
                borderRadius: BorderRadius.circular(kidRadius),
                border: Border.all(
                  color: leave ? colors.border : colors.primaryStrong,
                  width: leave ? 2 : 3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Mascot(
                    expression: expression,
                    size: _guide,
                    animate: false,
                    sparkles: false,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  mark,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl - AppSpacing.xs,
        0,
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          choice(
            leave: false,
            expression: MascotExpression.welcome,
            mark: Container(
              width: _mark,
              height: _mark,
              decoration: BoxDecoration(
                color: colors.primaryStrong,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: AppSizes.iconLg - AppSpacing.xs,
                color: colors.onPrimaryStrong,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          choice(
            leave: true,
            expression: MascotExpression.understand,
            mark: Container(
              width: _mark,
              height: _mark,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.border, width: 2),
              ),
              child: Center(
                child: AppIconView(
                  AppIcon.door,
                  size: AppSizes.iconLg - AppSpacing.xs,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A star flying on an arc from a right answer ([from]) to the bar's ([to]),
/// growing on the way, drawn above everything. Then [onLanded].
Future<void> flyKidStar(
  BuildContext context, {
  required TickerProvider vsync,
  required Rect from,
  required Rect to,
  required VoidCallback onLanded,
}) async {
  if (AppMotion.reduceMotion(context)) return onLanded();
  final overlay = Overlay.of(context);
  final flight = AnimationController(
    vsync: vsync,
    duration: AppMotion.kidStarFlight,
  );
  const size = 56.0;
  final a = from.center;
  final b = to.center;
  final control = Offset((a.dx + b.dx) / 2, (a.dy < b.dy ? a.dy : b.dy) - 90);
  final entry = OverlayEntry(
    builder: (_) => AnimatedBuilder(
      animation: flight,
      builder: (_, _) {
        final t = AppMotion.inOut.transform(flight.value);
        final u = 1 - t;
        final at = a * (u * u) + control * (2 * u * t) + b * (t * t);
        final scale = t < .5 ? 1 + 1.3 * t : 1.65 - 2.3 * (t - .5);
        return Positioned.fromRect(
          rect: Rect.fromCenter(center: at, width: size, height: size),
          child: IgnorePointer(
            child: Transform.scale(
              scale: scale,
              child: const KidStar(size: size),
            ),
          ),
        );
      },
    ),
  );
  overlay.insert(entry);
  try {
    await flight.forward().orCancel;
  } on TickerCanceled {
    // The lesson closed mid-flight.
  } finally {
    entry.remove();
    flight.dispose();
  }
  onLanded();
}
