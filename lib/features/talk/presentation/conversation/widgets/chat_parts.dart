import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/listening_motion.dart';
import 'package:englizia/core/design_system/widgets/ai_dots.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/presentation/widgets/talk_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A bubble's corners: round, but for the one on its speaker's side.
const _bubbleRadius = 20.0;
const _bubbleCorner = 6.0;
const _bubblePadding = EdgeInsetsDirectional.symmetric(
  horizontal: AppSpacing.md + AppSpacing.xxs,
  vertical: AppSpacing.sm + AppSpacing.xxs,
);
const _characterCorners = BorderRadiusDirectional.only(
  topStart: Radius.circular(_bubbleCorner),
  topEnd: Radius.circular(_bubbleRadius),
  bottomStart: Radius.circular(_bubbleRadius),
  bottomEnd: Radius.circular(_bubbleRadius),
);
const _mineCorners = BorderRadiusDirectional.only(
  topStart: Radius.circular(_bubbleRadius),
  topEnd: Radius.circular(_bubbleCorner),
  bottomStart: Radius.circular(_bubbleRadius),
  bottomEnd: Radius.circular(_bubbleRadius),
);

/// The character's small picture beside its bubbles.
const chatAvatar = 28.0;

/// English in a bubble, written left to right in either language.
Widget _english(BuildContext context, String text) => Text(
  text,
  textDirection: TextDirection.ltr,
  textAlign: TextAlign.start,
  style: context.texts.body.copyWith(color: context.colors.textPrimary),
);

/// A pill button of the chat: [filled] for the step forward.
class ChatPillButton extends StatelessWidget {
  const ChatPillButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.outlined = false,
    this.height = 36,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = filled
        ? colors.onPrimaryStrong
        : outlined
        ? colors.textPrimary
        : colors.primary.text;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(0, height),
        fixedSize: Size.fromHeight(height),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md + AppSpacing.xxs,
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: filled ? colors.primaryStrong : colors.surface,
        foregroundColor: ink,
        shape: StadiumBorder(
          side: outlined ? BorderSide(color: colors.border) : BorderSide.none,
        ),
        textStyle: context.texts.captionStrong,
      ),
      child: Text(label),
    );
  }
}

/// The character's line, its voice again, and its Arabic on demand. No
/// correction ever shows here (S §8.6).
class CharacterBubble extends StatelessWidget {
  const CharacterBubble({
    required this.line,
    required this.character,
    required this.showAvatar,
    required this.translated,
    required this.maxWidth,
    required this.onReplay,
    required this.onTranslate,
    super.key,
  });

  final TalkLine line;
  final TalkCharacter character;

  /// Only the first bubble of the character's turn has its picture.
  final bool showAvatar;
  final bool translated;
  final double maxWidth;
  final VoidCallback onReplay;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility.maintain(
              visible: showAvatar,
              child: CharacterAvatar(
                character: character,
                size: chatAvatar,
                kind: TalkKind.ai,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: _bubblePadding,
                    decoration: BoxDecoration(
                      color: colors.ai.surface,
                      borderRadius: _characterCorners,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _english(context, line.english),
                        if (translated && line.arabic.isNotEmpty) ...[
                          const SizedBox(
                            height: AppSpacing.xs + AppSpacing.xxs,
                          ),
                          Divider(
                            height: 1,
                            color: context.scheme.outlineVariant,
                          ),
                          const SizedBox(
                            height: AppSpacing.xs + AppSpacing.xxs,
                          ),
                          Text(
                            line.arabic,
                            textDirection: TextDirection.rtl,
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                              fontSize: texts.body.fontSize! * .875,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (line.audioUrl != null)
                        IconButton(
                          onPressed: onReplay,
                          tooltip: 'talk_replay'.tr(),
                          iconSize: AppSizes.iconSm,
                          color: colors.info.fill,
                          icon: const Icon(Icons.volume_up_rounded),
                        ),
                      if (line.arabic.isNotEmpty)
                        TextButton(
                          onPressed: onTranslate,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            textStyle: texts.captionStrong.copyWith(
                              fontSize: texts.caption.fontSize! * .92,
                            ),
                          ),
                          child: Text(
                            translated
                                ? 'talk_hide_translation'.tr()
                                : 'talk_translate'.tr(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the learner said, and whether they spoke or typed it.
class MineBubble extends StatelessWidget {
  const MineBubble({
    required this.text,
    required this.via,
    required this.maxWidth,
    super.key,
  });

  final String text;
  final SaidVia via;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: _bubblePadding,
              decoration: BoxDecoration(
                color: colors.primary.surface,
                borderRadius: _mineCorners,
              ),
              child: _english(context, text),
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              container: true,
              label: via == SaidVia.mic ? 'talk_said'.tr() : 'talk_typed'.tr(),
              excludeSemantics: true,
              child: Icon(
                via == SaidVia.mic
                    ? Icons.mic_none_rounded
                    : Icons.keyboard_alt_outlined,
                size: AppSizes.iconSm * .875,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The character thinks: three violet dots in its bubble.
class ThinkingBubble extends StatelessWidget {
  const ThinkingBubble({required this.character, super.key});

  final TalkCharacter character;

  static const _height = 44.0;
  static const _dot = 8.0;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'talk_thinking'.tr(namedArgs: {'name': character.name}),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterAvatar(
            character: character,
            size: chatAvatar,
            kind: TalkKind.ai,
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            height: _height,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.ai.surface,
              borderRadius: _characterCorners,
            ),
            child: const AiDots(dot: _dot),
          ),
        ],
      ),
    ),
  );
}

/// «تعذّر الرد»: the conversation goes on, and the turn didn't count.
class ReplyFailed extends StatelessWidget {
  const ReplyFailed({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.xs + AppSpacing.xxs,
            AppSpacing.xs + AppSpacing.xxs,
            AppSpacing.xs + AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.info.surface,
            borderRadius: BorderRadius.circular(AppRadius.md + AppSpacing.xxs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconView(
                AppIcon.infoCircle,
                size: AppSizes.iconSm + AppSpacing.xxs,
                color: colors.info.fill,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'talk_reply_failed'.tr(),
                  style: context.texts.caption.copyWith(
                    color: colors.info.text,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChatPillButton(
                label: 'common_retry'.tr(),
                onPressed: onRetry,
                height: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the microphone understood, dashed until sent: speech to text makes
/// mistakes, so the learner reads it first (S §8.6). Nothing is corrected.
class DraftBubble extends StatelessWidget {
  const DraftBubble({
    required this.text,
    required this.maxWidth,
    required this.onRedo,
    required this.onSend,
    super.key,
  });

  final String text;
  final double maxWidth;
  final VoidCallback onRedo;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DashedBorder(
              color: colors.primaryStrong,
              radius: _bubbleRadius,
              width: 1.5,
              child: Container(
                padding: _bubblePadding,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: _mineCorners,
                ),
                child: _english(context, text),
              ),
            ),
            const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatPillButton(
                  label: 'talk_redo'.tr(),
                  onPressed: onRedo,
                  outlined: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                ChatPillButton(
                  label: 'talk_send'.tr(),
                  onPressed: onSend,
                  filled: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The tasks under the bar, with the turns left. A task just done fills in,
/// draws its check and is struck through.
class TaskPanel extends StatelessWidget {
  const TaskPanel({
    required this.tasks,
    required this.done,
    required this.justDone,
    required this.turnsLeft,
    super.key,
  });

  final List<TalkTask> tasks;
  final Set<String> done;
  final Set<String> justDone;
  final int turnsLeft;

  static const _circle = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final reduce = AppMotion.reduceMotion(context);
    return Semantics(
      container: true,
      label: 'talk_your_tasks'.tr(),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.md + AppSpacing.xxs,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.border)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: .1),
              blurRadius: AppSpacing.md,
              offset: const Offset(0, AppSpacing.sm),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final task in tasks) ...[
              Row(
                children: [
                  _mark(
                    context,
                    done.contains(task.id),
                    animate: !reduce && justDone.contains(task.id),
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      task.text,
                      style: texts.caption.copyWith(
                        fontSize: texts.body.fontSize! * .875,
                        color: done.contains(task.id)
                            ? colors.textSecondary
                            : colors.textPrimary,
                        decoration: done.contains(task.id)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            ],
            Text(
              'talk_turns_left'.tr(namedArgs: {'count': '$turnsLeft'}),
              style: texts.caption.copyWith(
                color: colors.textSecondary,
                fontSize: texts.caption.fontSize! * .92,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mark(BuildContext context, bool isDone, {required bool animate}) {
    final colors = context.colors;
    final circle = Container(
      width: _circle,
      height: _circle,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? colors.success.fill : null,
        border: isDone ? null : Border.all(color: colors.border, width: 1.5),
      ),
      child: isDone
          ? Icon(
              Icons.check_rounded,
              size: AppSizes.iconSm * .875,
              color: colors.onPrimaryStrong,
            )
          : null,
    );
    final mark = Semantics(
      checked: isDone,
      excludeSemantics: true,
      child: circle,
    );
    if (!animate) return mark;
    return mark.animate().scaleXY(
      begin: .4,
      end: 1,
      delay: AppMotion.taskPopDelay,
      duration: AppMotion.taskPop,
      curve: AppMotion.overshoot,
    );
  }
}

/// «جرّب أن تقول»: each one only heard, as the learner says it themselves.
class Suggestions extends StatelessWidget {
  const Suggestions({required this.lines, required this.onPlay, super.key});

  final List<TalkLine> lines;
  final ValueChanged<TalkLine> onPlay;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xl - AppSpacing.xs,
          ),
          child: Text(
            'talk_try_saying'.tr(),
            style: texts.caption.copyWith(
              color: colors.textSecondary,
              fontSize: texts.caption.fontSize! * .92,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
        SizedBox(
          height: _height + AppSpacing.xs,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            itemCount: lines.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final line = lines[index];
              return Align(
                alignment: AlignmentDirectional.topCenter,
                child: OutlinedButton.icon(
                  onPressed: line.audioUrl == null ? null : () => onPlay(line),
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size.fromHeight(_height),
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.sm + AppSpacing.xxs,
                      0,
                      AppSpacing.md + AppSpacing.xxs,
                      0,
                    ),
                    backgroundColor: colors.surface,
                    foregroundColor: colors.textPrimary,
                    disabledForegroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    Icons.volume_up_rounded,
                    size: AppSizes.iconSm,
                    color: colors.info.fill,
                  ),
                  label: Text(
                    line.english,
                    textDirection: TextDirection.ltr,
                    style: texts.caption.copyWith(
                      color: colors.textPrimary,
                      fontSize: texts.body.fontSize! * .875,
                      height: 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The conversation is over: every task done, or the turns used up.
class ChatEnded extends StatelessWidget {
  const ChatEnded({
    required this.taskCount,
    required this.allDone,
    required this.onSummary,
    super.key,
  });

  final int taskCount;
  final bool allDone;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = !allDone
        ? 'talk_turns_over'.tr()
        : switch (taskCount) {
            2 => 'talk_all_done_2'.tr(),
            4 => 'talk_all_done_4'.tr(),
            _ => 'talk_all_done_3'.tr(),
          };
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md + AppSpacing.xxs,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.success.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: AppSizes.iconMd - AppSpacing.xxs,
              color: colors.success.fill,
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Expanded(
              child: Text(
                title,
                style: context.texts.captionStrong.copyWith(
                  color: colors.success.text,
                  fontSize: context.texts.body.fontSize! * .875,
                ),
              ),
            ),
            ChatPillButton(
              label: 'talk_summary'.tr(),
              onPressed: onSummary,
              filled: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The big microphone, its ring while it records, and the keyboard instead.
class MicBar extends StatelessWidget {
  const MicBar({
    required this.recording,
    required this.onMic,
    required this.onKeyboard,
    super.key,
  });

  final bool recording;
  final VoidCallback onMic;
  final VoidCallback onKeyboard;

  static const _height = 96.0;
  static const _mic = 72.0;
  static const _halo = 6.0;
  static const _keyboard = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: _height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: _mic,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ListeningWaves(
                  active: recording,
                  size: _mic,
                  count: 1,
                  growth: .5,
                  opacity: .3,
                  filled: true,
                  duration: AppMotion.micRing,
                  color: colors.primary.fill,
                ),
                Semantics(
                  button: true,
                  toggled: recording,
                  label: 'talk_speak'.tr(),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onMic,
                    child: Container(
                      width: _mic,
                      height: _mic,
                      decoration: BoxDecoration(
                        color: colors.primaryStrong,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.surface,
                            spreadRadius: _halo,
                          ),
                        ],
                      ),
                      child: Icon(
                        recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                        size: AppSizes.iconLg - AppSpacing.xxs,
                        color: colors.onPrimaryStrong,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppSpacing.xl - AppSpacing.xs,
              ),
              child: IconButton(
                onPressed: onKeyboard,
                tooltip: 'talk_type_instead'.tr(),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(_keyboard),
                  backgroundColor: colors.surface,
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                ),
                iconSize: AppSizes.iconMd - AppSpacing.xxs,
                icon: const Icon(Icons.keyboard_alt_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Typing instead: English only, with the microphone a tap away.
class TypeBar extends StatelessWidget {
  const TypeBar({
    required this.controller,
    required this.focusNode,
    required this.onMic,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onMic;
  final VoidCallback onSend;

  static const _field = 48.0;
  static const _mic = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    OutlineInputBorder edge(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_field / 2),
      borderSide: BorderSide(color: color, width: width),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMic,
            tooltip: 'talk_speak_instead'.tr(),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(_mic),
              backgroundColor: colors.surface,
              foregroundColor: colors.primaryStrong,
              side: BorderSide(color: colors.border),
            ),
            iconSize: AppSizes.iconMd - AppSpacing.xs,
            icon: const Icon(Icons.mic_none_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(
              height: _field,
              child: Semantics(
                label: 'talk_type_label'.tr(),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: texts.body.copyWith(
                    color: colors.textPrimary,
                    fontSize: texts.body.fontSize! * .94,
                  ),
                  decoration: InputDecoration(
                    hintText: 'talk_type_hint'.tr(),
                    hintTextDirection: TextDirection.ltr,
                    hintStyle: texts.body.copyWith(
                      color: colors.textSecondary,
                      fontSize: texts.body.fontSize! * .94,
                    ),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg + AppSpacing.xxs,
                    ),
                    enabledBorder: edge(colors.border, 1),
                    focusedBorder: edge(colors.primaryStrong, 2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) {
              final ready = value.text.trim().isNotEmpty;
              return Semantics(
                button: true,
                enabled: ready,
                label: 'talk_send'.tr(),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: ready ? onSend : null,
                  child: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.quick),
                    width: _field,
                    height: _field,
                    decoration: BoxDecoration(
                      color: ready ? colors.primaryStrong : colors.border,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: AppSizes.iconMd - AppSpacing.xxs,
                      color: colors.onPrimaryStrong,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A new bubble grows in.
Widget bubbleEntrance(Widget child) => Entrance(
  motion: EntranceMotion.pop,
  delay: Duration.zero,
  duration: AppMotion.bubbleIn,
  child: child,
);
