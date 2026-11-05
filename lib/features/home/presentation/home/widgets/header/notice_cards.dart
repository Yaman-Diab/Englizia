import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/header_styles.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:flutter/material.dart';

enum _NoticeKind { levelCheck, placement, freeze, broke }

/// The notice slot's cards (design "Home Archipelago", header §7.2–§7.4):
/// the level check, the deferred placement test, a freeze used and a streak
/// ended. Each is a live region with the design's label; the freeze and broke
/// cards carry the guide (shown while [showGuide]; [guideKey] marks its 56
/// box for the flight to the ring) and close with an X pulled into the end
/// corner (header §16.14). Shares its name with the core `NoticeCard`: a file
/// using both imports one with a prefix.
class NoticeCard extends StatelessWidget {
  const NoticeCard.levelCheck({required VoidCallback this.onStart, super.key})
    : _kind = _NoticeKind.levelCheck,
      minutes = null,
      event = null,
      streak = null,
      perWeek = 0,
      showGuide = false,
      guideKey = null,
      onClose = null;

  const NoticeCard.placement({
    required ({int min, int max}) this.minutes,
    required VoidCallback this.onStart,
    super.key,
  }) : _kind = _NoticeKind.placement,
       event = null,
       streak = null,
       perWeek = 0,
       showGuide = false,
       guideKey = null,
       onClose = null;

  const NoticeCard.freeze({
    required HomeEvent this.event,
    required Streak this.streak,
    required this.perWeek,
    required this.showGuide,
    required VoidCallback this.onClose,
    this.guideKey,
    super.key,
  }) : _kind = _NoticeKind.freeze,
       minutes = null,
       onStart = null;

  const NoticeCard.broke({
    required HomeEvent this.event,
    required this.showGuide,
    required VoidCallback this.onClose,
    this.guideKey,
    super.key,
  }) : _kind = _NoticeKind.broke,
       minutes = null,
       streak = null,
       perWeek = 0,
       onStart = null;

  final _NoticeKind _kind;
  final ({int min, int max})? minutes;
  final HomeEvent? event;
  final Streak? streak;

  /// Freezes added each week; 0 leaves out «يُضاف واحد كل أسبوع.».
  final int perWeek;
  final bool showGuide;
  final Key? guideKey;
  final VoidCallback? onStart;
  final VoidCallback? onClose;

  /// The cards' heights in the design; a card grows with its text.
  static const freezeHeight = 108.0;
  static const brokeHeight = 92.0;
  static const offerHeight = 80.0;

  static const _guide = 56.0;

  /// «بقي تجميد واحد من 3.».
  static String freezesLeft(HomeEvent event, Streak streak) =>
      'home_freeze_left'.plural(
        event.freezesLeft ?? streak.freezes,
        namedArgs: {'max': '${streak.maxFreezes}'},
      );

  /// «12 إلى 15 دقيقة لتبدأ من المستوى المناسب».
  static String placementBody(({int min, int max}) minutes) => 'home_test_body'
      .plural(minutes.max, namedArgs: {'min': '${minutes.min}'});

  @override
  Widget build(BuildContext context) => switch (_kind) {
    _NoticeKind.levelCheck => _Offer(
      icon: AppIcon.target,
      title: 'home_check_title'.tr(),
      body: 'home_check_body'.tr(),
      action: 'home_check_start'.tr(),
      label: 'home_check_semantics'.tr(),
      onStart: onStart!,
    ),
    _NoticeKind.placement => _Offer(
      icon: AppIcon.gauge,
      title: 'home_test_title'.tr(),
      body: placementBody(minutes!),
      action: 'unit_start'.tr(),
      label: 'home_test_semantics'.tr(args: [placementBody(minutes!)]),
      onStart: onStart!,
    ),
    _NoticeKind.freeze => _freeze(context),
    _NoticeKind.broke => _broke(context),
  };

  Widget _freeze(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final event = this.event!;
    final streak = this.streak!;
    final left = freezesLeft(event, streak);
    final sub = perWeek > 0
        ? 'home_freeze_sub'.tr(
            namedArgs: {
              'left': left,
              'weekly': 'home_freeze_weekly'.plural(perWeek),
            },
          )
        : left;
    return _Card(
      label: 'home_freeze_semantics'.tr(
        namedArgs: {'days': yourDays(event.streak), 'left': left},
      ),
      color: colors.info.surface,
      height: freezeHeight,
      guide: _cardGuide(MascotExpression.happy),
      onClose: onClose!,
      texts: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 1,
        children: [
          Row(
            children: [
              AppIconView(AppIcon.snowflake, size: 16, color: colors.info.fill),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'home_freeze_kicker'.tr(),
                  style: texts.captionStrong.copyWith(
                    fontSize: 12,
                    height: 18 / 12,
                    color: colors.info.text,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'home_freeze_title'.tr(args: [yourDays(event.streak)]),
            style: _title(context),
          ),
          Text(sub, style: _sub(context)),
        ],
      ),
    );
  }

  Widget _broke(BuildContext context) {
    final colors = context.colors;
    final event = this.event!;
    final days = daysText(event.streak);
    return _Card(
      label: 'home_broke_semantics'.tr(args: [days]),
      color: colors.surface,
      bordered: true,
      height: brokeHeight,
      guide: _cardGuide(MascotExpression.encourage),
      onClose: onClose!,
      texts: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text('home_broke_title'.tr(), style: _title(context)),
          Text('home_broke_sub'.tr(args: [days]), style: _sub(context)),
        ],
      ),
    );
  }

  Widget _cardGuide(MascotExpression expression) => SizedBox.square(
    key: guideKey,
    dimension: _guide,
    child: showGuide
        ? Mascot(expression: expression, size: _guide, sparkles: false)
        : null,
  );
}

TextStyle _title(BuildContext context) => headerText(
  context,
  context.texts.bodyStrong,
  size: 14,
  line: 20,
).copyWith(color: context.colors.textPrimary);

TextStyle _sub(BuildContext context) => headerText(
  context,
  context.texts.caption,
  size: 12,
  line: 18,
).copyWith(color: context.colors.textSecondary);

/// The one-time cards: the guide, the texts, the X.
class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.color,
    required this.height,
    required this.guide,
    required this.texts,
    required this.onClose,
    this.bordered = false,
  });

  final String label;
  final Color color;
  final double height;
  final Widget guide;
  final Widget texts;
  final VoidCallback onClose;
  final bool bordered;

  static const _close = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      explicitChildNodes: true,
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 2, 10),
        decoration: _cardDecoration(color, bordered ? scheme.outline : null),
        child: Row(
          children: [
            ExcludeSemantics(child: guide),
            const SizedBox(width: 12),
            Expanded(child: ExcludeSemantics(child: texts)),
            HeaderTap(
              label: 'home_close'.tr(),
              onTap: onClose,
              margin: const EdgeInsets.all(2),
              builder: (context, pressed) => Container(
                width: _close,
                height: _close,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pressed
                      ? scheme.surfaceContainerHigh
                      : Colors.transparent,
                ),
                child: AppIconView(
                  AppIcon.cross,
                  size: 20,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The level check and the deferred test: an icon in a disk, the texts, a
/// small outlined button.
class _Offer extends StatelessWidget {
  const _Offer({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.label,
    required this.onStart,
  });

  final AppIcon icon;
  final String title;
  final String body;
  final String action;
  final String label;
  final VoidCallback onStart;

  static const _disk = 40.0;
  static const _icon = 22.0;
  static const _button = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      explicitChildNodes: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: NoticeCard.offerHeight),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: _cardDecoration(colors.surface, scheme.outline),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: _disk,
                height: _disk,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.surface,
                ),
                child: AppIconView(
                  icon,
                  size: _icon,
                  color: colors.primaryStrong,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _title(context)),
                    Text(body, style: _sub(context)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            HeaderTap(
              label: action,
              onTap: onStart,
              margin: const EdgeInsetsDirectional.symmetric(vertical: 4),
              builder: (context, pressed) => Container(
                height: _button,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pressed ? scheme.surfaceContainerHigh : colors.surface,
                  borderRadius: BorderRadius.circular(_button / 2),
                  border: Border.all(color: scheme.outline, width: 1.5),
                ),
                child: Text(
                  action,
                  maxLines: 1,
                  softWrap: false,
                  style: context.texts.captionStrong.copyWith(
                    height: 1,
                    color: colors.primary.text,
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

BoxDecoration _cardDecoration(Color color, Color? border) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(_cardRadius),
  border: border == null ? null : Border.all(color: border),
);

const _cardRadius = 20.0;
