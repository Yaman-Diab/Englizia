import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/grammar/widgets/grammar_player.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_text_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The sound's player at the foot of the screen, left to right in any app language.
class ReaderPlayerBar extends StatelessWidget {
  const ReaderPlayerBar({required this.state, super.key});

  final InteractiveTextState state;

  static const height = 88.0;
  static const _play = 56.0;
  static const _iconSize = 28.0;

  String _speedText(double speed) =>
      speed == speed.truncateToDouble() ? '${speed.toInt()}' : '$speed';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<InteractiveTextCubit>();
    final content = state.content!;
    final total = content.duration.inMilliseconds;
    final share = total == 0
        ? 0.0
        : (state.position.inMilliseconds / total).clamp(0.0, 1.0);
    final small = texts.caption.copyWith(
      color: colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final speed = _speedText(state.speed);
    final appDirection = Directionality.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Opacity(
                opacity: state.audioFailed ? .38 : 1,
                child: PressScale(
                  child: Semantics(
                    button: true,
                    label: state.playing
                        ? 'reader_pause'.tr()
                        : 'reader_play'.tr(),
                    excludeSemantics: true,
                    child: Material(
                      color: colors.primaryStrong,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: state.audioFailed ? null : cubit.togglePlay,
                        child: SizedBox.square(
                          dimension: _play,
                          child: Icon(
                            state.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: _iconSize,
                            color: colors.onPrimaryStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      slider: true,
                      label: 'reader_position'.tr(),
                      value: videoTime(state.position),
                      excludeSemantics: true,
                      child: LayoutBuilder(
                        builder: (context, box) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) => cubit.seekTo(
                            content.duration *
                                (details.localPosition.dx / box.maxWidth).clamp(
                                  0.0,
                                  1.0,
                                ),
                          ),
                          onHorizontalDragUpdate: (details) => cubit.seekTo(
                            content.duration *
                                (details.localPosition.dx / box.maxWidth).clamp(
                                  0.0,
                                  1.0,
                                ),
                          ),
                          child: SizedBox(
                            height: AppSpacing.lg,
                            child: Stack(
                              alignment: AlignmentDirectional.centerStart,
                              children: [
                                _Track(
                                  width: box.maxWidth,
                                  color: context.scheme.outline.withValues(
                                    alpha: .55,
                                  ),
                                ),
                                _Track(
                                  width: box.maxWidth * share,
                                  color: colors.primary.fill,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(videoTime(state.position), style: small),
                        Flexible(
                          child: Directionality(
                            textDirection: appDirection,
                            child: Text(
                              'reader_sentence_of'.tr(
                                namedArgs: {
                                  'at': '${state.current + 1}',
                                  'of': '${content.sentences.length}',
                                },
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: small,
                            ),
                          ),
                        ),
                        Text(videoTime(content.duration), style: small),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Semantics(
                button: true,
                label: 'reader_speed_now'.tr(namedArgs: {'speed': speed}),
                excludeSemantics: true,
                child: OutlinedButton(
                  onPressed: cubit.cycleSpeed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: context.scheme.outline),
                    minimumSize: const Size.square(AppSizes.minTapTarget),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('$speed×', style: texts.captionStrong),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.width, required this.color});

  final double width;
  final Color color;

  static const _height = 4.0;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: _height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(_height / 2),
    ),
  );
}

/// «تعذّر تحميل الصوت»: the text and its cards go on working.
class ReaderAudioFailed extends StatelessWidget {
  const ReaderAudioFailed({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: colors.info.surface,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.lg,
            end: AppSpacing.sm,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              AppIconView(
                AppIcon.volumeOff,
                size: AppSizes.iconSm + AppSpacing.xxs,
                color: colors.info.fill,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'reader_audio_failed'.tr(),
                  style: context.texts.caption.copyWith(
                    color: colors.info.text,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: Text('reader_retry'.tr())),
            ],
          ),
        ),
      ),
    );
  }
}

/// «الجملة الحالية», over the player once the learner has scrolled away.
class ReaderBackToCurrent extends StatelessWidget {
  const ReaderBackToCurrent({
    required this.upward,
    required this.onTap,
    super.key,
  });

  /// The sentence is above what shows.
  final bool upward;
  final VoidCallback onTap;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: Material(
        color: colors.textPrimary,
        shape: const StadiumBorder(),
        elevation: AppSpacing.xs,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md,
                end: AppSpacing.lg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    upward
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: AppSizes.iconSm + AppSpacing.xxs,
                    color: colors.background,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'reader_back_to_current'.tr(),
                    style: context.texts.captionStrong.copyWith(
                      color: colors.background,
                    ),
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

/// «حُفظت في بنك الكلمات», with the way to see them.
class ReaderSavedNotice extends StatelessWidget {
  const ReaderSavedNotice({required this.onShow, super.key});

  final VoidCallback onShow;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _height),
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              Icons.star_rounded,
              size: AppSizes.iconSm + AppSpacing.xxs,
              color: colors.reward.fill,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'reader_saved_notice'.tr(),
                style: context.texts.caption.copyWith(color: colors.background),
              ),
            ),
            TextButton(
              onPressed: onShow,
              style: TextButton.styleFrom(
                foregroundColor: colors.reader.karaokeBackground,
              ),
              child: Text('reader_saved_show'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end of the list: how much there was, and the way on.
class ReaderEnd extends StatelessWidget {
  const ReaderEnd({
    required this.sentences,
    required this.savedCount,
    required this.markedCount,
    required this.hasShadowing,
    required this.guide,
    required this.onContinue,
    super.key,
  });

  final int sentences;
  final int savedCount;
  final int markedCount;
  final bool hasShadowing;
  final Widget guide;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xl),
      child: Column(
        children: [
          guide,
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              'reader_end_title'.tr(),
              style: texts.title.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              'reader_end_sentences'.plural(sentences),
              if (savedCount > 0)
                'reader_end_saved'.plural(savedCount)
              else if (markedCount > 0)
                'reader_end_marked'.plural(markedCount),
            ].join(' · '),
            textAlign: TextAlign.center,
            style: texts.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          AppButton(
            label: hasShadowing
                ? 'reader_continue_shadowing'.tr()
                : 'reader_continue_exercises'.tr(),
            size: AppButtonSize.large,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

/// How the text shows: its size, its way, and stopping after each sentence. All of
/// it stays on the phone.
Future<void> showReaderSettings(BuildContext context) {
  final cubit = context.read<InteractiveTextCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: sheetAnimation(context),
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const _ReaderSettings()),
  );
}

class _ReaderSettings extends StatelessWidget {
  const _ReaderSettings();

  static const _sizeHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<InteractiveTextCubit>();
    return BlocSelector<
      InteractiveTextCubit,
      InteractiveTextState,
      ReaderPrefs
    >(
      selector: (state) => state.prefs,
      builder: (context, prefs) {
        final heading = texts.bodyStrong.copyWith(color: colors.textPrimary);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg + AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.lg + AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('reader_size_title'.tr(), style: heading),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (final (i, size) in ReaderTextSize.values.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ChoiceSurface(
                          selected: prefs.size == size,
                          onTap: () =>
                              cubit.setPrefs(prefs.copyWith(size: size)),
                          semanticLabel: _sizeName(size),
                          radius: AppRadius.md,
                          child: SizedBox(
                            height: _sizeHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'reader_size_sample'.tr(),
                                  textDirection: TextDirection.ltr,
                                  style: readerSample(context, size),
                                ),
                                Text(
                                  _sizeName(size),
                                  style: texts.caption.copyWith(
                                    color: colors.textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                Text('reader_mode_title'.tr(), style: heading),
                const SizedBox(height: AppSpacing.xs),
                for (final mode in ReaderMode.values)
                  _ModeRow(
                    mode: mode,
                    selected: prefs.mode == mode,
                    onTap: () => cubit.setPrefs(prefs.copyWith(mode: mode)),
                  ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsetsDirectional.zero,
                  value: prefs.stopEachSentence,
                  onChanged: (on) =>
                      cubit.setPrefs(prefs.copyWith(stopEachSentence: on)),
                  title: Text(
                    'reader_stop_each'.tr(),
                    style: texts.captionStrong.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'reader_stop_each_detail'.tr(),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'reader_settings_done'.tr(),
                  size: AppButtonSize.large,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _sizeName(ReaderTextSize size) => switch (size) {
    ReaderTextSize.small => 'reader_size_small'.tr(),
    ReaderTextSize.medium => 'reader_size_medium'.tr(),
    ReaderTextSize.large => 'reader_size_large'.tr(),
  };
}

/// `Aa` at the size it stands for.
TextStyle readerSample(BuildContext context, ReaderTextSize size) {
  final base = context.texts.bodyStrong;
  final share = switch (size) {
    ReaderTextSize.small => 18 / 16,
    ReaderTextSize.medium => 20 / 16,
    ReaderTextSize.large => 24 / 16,
  };
  return base.copyWith(
    fontSize: base.fontSize! * share,
    color: context.colors.textPrimary,
    height: 1.1,
  );
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ReaderMode mode;
  final bool selected;
  final VoidCallback onTap;

  static const _minHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final (String label, String? detail) = switch (mode) {
      ReaderMode.onTap => (
        'reader_mode_tap'.tr(),
        'reader_mode_tap_detail'.tr(),
      ),
      ReaderMode.below => ('reader_mode_below'.tr(), null),
      ReaderMode.arabicFirst => ('reader_mode_arabic_first'.tr(), null),
      ReaderMode.arabicOnly => ('reader_mode_arabic_only'.tr(), null),
      ReaderMode.listening => (
        'reader_mode_listening'.tr(),
        'reader_mode_listening_detail'.tr(),
      ),
    };
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Row(
            children: [
              ChoiceRadio(selected: selected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: AppMotion.resolve(context, AppMotion.quick),
                      style: (selected ? texts.captionStrong : texts.caption)
                          .copyWith(color: colors.textPrimary),
                      child: Text(label),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
