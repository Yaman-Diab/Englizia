import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/teacher_questions_cubit.dart';
import 'package:englizia/features/lessons/presentation/video/lesson_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "When" in words, as the server's time is exact and the learner doesn't need it.
String _ago(DateTime at) {
  final passed = DateTime.now().difference(at);
  if (passed.inMinutes < 1) return 'lesson_q_now'.tr();
  if (passed.inHours < 1) return 'lesson_q_minutes'.plural(passed.inMinutes);
  if (passed.inDays < 1) return 'lesson_q_hours'.plural(passed.inHours);
  return 'lesson_q_days'.plural(passed.inDays);
}

/// The learner's own questions on the lesson, under the video. The design had the
/// class's questions here; the owner made them private (ADR 14), so the title and
/// the words say whose they are, and there are no other learners to report or block.
class TeacherQuestionsSection extends StatelessWidget {
  const TeacherQuestionsSection({required this.videoPosition, super.key});

  /// Where the video is now, saved with a question asked from here.
  final Duration Function() videoPosition;

  static const _preview = 2;
  static const _countHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return BlocBuilder<TeacherQuestionsCubit, TeacherQuestionsState>(
      builder: (context, state) {
        if (state.load != LoadStatus.ready) return const SizedBox.shrink();
        final questions = state.questions;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'lesson_q_title'.tr(),
                    style: texts.bodyStrong.copyWith(color: colors.textPrimary),
                  ),
                ),
                if (questions.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    height: _countHeight,
                    constraints: const BoxConstraints(minWidth: _countHeight),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(_countHeight / 2),
                      border: Border.all(color: context.scheme.outline),
                    ),
                    child: Text(
                      '${questions.length}',
                      style: texts.captionStrong.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'lesson_q_private'.tr(),
              style: texts.caption.copyWith(color: colors.textSecondary),
            ),
            for (final question in questions.take(_preview))
              QuestionCard(question: question),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    showTeacherQuestions(context, videoPosition: videoPosition),
                child: Text(
                  questions.isEmpty ? 'lesson_q_ask'.tr() : 'lesson_q_all'.tr(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class QuestionCard extends StatelessWidget {
  const QuestionCard({required this.question, super.key});

  final TeacherQuestion question;

  static const _avatar = 32.0;
  static const _replyAvatar = 28.0;
  static const _replyIndent = 42.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final reply = question.reply;
    final at = question.videoPosition;
    final meta = [
      _ago(question.askedAt),
      if (at != null)
        'lesson_q_at_video'.tr(namedArgs: {'time': videoTime(at)}),
    ].join(' · ');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Initial(
                  letter: 'lesson_q_you'.tr().characters.first,
                  size: _avatar,
                  color: colors.info.surface,
                  ink: colors.info.text,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'lesson_q_you'.tr(),
                        style: texts.captionStrong.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        meta,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        question.text,
                        style: texts.body.copyWith(color: colors.textPrimary),
                      ),
                      _Delivery(question: question),
                    ],
                  ),
                ),
              ],
            ),
            if (reply != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: _replyIndent,
                  top: AppSpacing.md,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(
                        color: colors.primary.surface,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Initial(
                          letter: reply.name.characters.first,
                          size: _replyAvatar,
                          color: colors.primary.surface,
                          ink: colors.primary.text,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    reply.name,
                                    style: texts.captionStrong.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    padding:
                                        const EdgeInsetsDirectional.symmetric(
                                          horizontal: AppSpacing.xs,
                                          vertical: AppSpacing.xxs,
                                        ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.surface,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.xs,
                                      ),
                                    ),
                                    child: Text(
                                      switch (reply.role) {
                                        ReplierRole.teacher =>
                                          'lesson_q_role_teacher'.tr(),
                                        ReplierRole.admin =>
                                          'lesson_q_role_admin'.tr(),
                                      },
                                      style: texts.caption.copyWith(
                                        color: colors.primary.text,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                reply.text,
                                style: texts.body.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
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
    );
  }
}

/// How the question stands: on its way, not sent, or waiting for an answer.
class _Delivery extends StatelessWidget {
  const _Delivery({required this.question});

  final TeacherQuestion question;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return switch (question.status) {
      QuestionStatus.sending => Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
        child: AppSpinner(size: AppSizes.iconSm, color: colors.textSecondary),
      ),
      QuestionStatus.failed => Row(
        children: [
          Flexible(
            child: Text(
              'lesson_q_not_sent'.tr(),
              style: texts.caption.copyWith(color: colors.error.text),
            ),
          ),
          TextButton(
            onPressed: () =>
                context.read<TeacherQuestionsCubit>().resend(question),
            child: Text('lesson_q_resend'.tr()),
          ),
        ],
      ),
      QuestionStatus.sent when question.reply == null => Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
        child: Text(
          'lesson_q_waiting'.tr(),
          style: texts.caption.copyWith(color: colors.textSecondary),
        ),
      ),
      QuestionStatus.sent => const SizedBox.shrink(),
    };
  }
}

class _Initial extends StatelessWidget {
  const _Initial({
    required this.letter,
    required this.size,
    required this.color,
    required this.ink,
  });

  final String letter;
  final double size;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: context.texts.captionStrong.copyWith(color: ink),
      ),
    ),
  );
}

/// All the learner's questions, on the whole screen, with the field to ask more.
Future<void> showTeacherQuestions(
  BuildContext context, {
  required Duration Function() videoPosition,
}) {
  final cubit = context.read<TeacherQuestionsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    backgroundColor: context.colors.background,
    sheetAnimationStyle: sheetAnimation(context),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _QuestionsSheet(videoPosition: videoPosition),
    ),
  );
}

class _QuestionsSheet extends StatefulWidget {
  const _QuestionsSheet({required this.videoPosition});

  final Duration Function() videoPosition;

  @override
  State<_QuestionsSheet> createState() => _QuestionsSheetState();
}

class _QuestionsSheetState extends State<_QuestionsSheet> {
  static const _guide = 120.0;
  static const _send = AppSizes.minTapTarget;

  final _draft = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _ask() {
    final text = _draft.text;
    if (text.trim().isEmpty) return;
    final position = widget.videoPosition();
    _draft.clear();
    setState(() {});
    context.read<TeacherQuestionsCubit>().ask(
      text,
      videoPosition: position > Duration.zero ? position : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final canSend = _draft.text.trim().isNotEmpty;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.minTapTarget / 2),
      borderSide: BorderSide(color: color, width: width),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: BlocBuilder<TeacherQuestionsCubit, TeacherQuestionsState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.md,
                    end: AppSpacing.xl,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'common_close'.tr(),
                        color: colors.textSecondary,
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'lesson_q_title'.tr(),
                            style: texts.bodyStrong.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (state.questions.isNotEmpty)
                        Text(
                          'lesson_q_count'.plural(state.questions.length),
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: state.questions.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsetsDirectional.all(
                            AppSpacing.xl,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Mascot(
                                expression: MascotExpression.curious,
                                size: _guide,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'lesson_q_empty_title'.tr(),
                                style: texts.bodyStrong.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'lesson_q_empty_body'.tr(),
                                textAlign: TextAlign.center,
                                style: texts.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'lesson_q_private'.tr(),
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            'lesson_q_newest'.tr(),
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          for (final question in state.questions)
                            QuestionCard(question: question),
                        ],
                      ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _draft,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            onChanged: (_) => setState(() {}),
                            style: texts.body.copyWith(
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'lesson_q_field'.tr(),
                              filled: true,
                              fillColor: colors.background,
                              enabledBorder: border(context.scheme.outline, 1),
                              focusedBorder: border(colors.primaryStrong, 2),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          onPressed: canSend ? _ask : null,
                          tooltip: 'lesson_q_send'.tr(),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.primaryStrong,
                            foregroundColor: colors.onPrimaryStrong,
                            disabledBackgroundColor: context.scheme.outline,
                            disabledForegroundColor: colors.onPrimaryStrong,
                            fixedSize: const Size.square(_send),
                          ),
                          icon: const Icon(Icons.send_rounded),
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
    );
  }
}
