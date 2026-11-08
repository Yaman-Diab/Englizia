import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/play_sound.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/lesson_picture.dart';
import 'package:flutter/material.dart';

enum _Side { meaning, word }

final class _Pick {
  const _Pick(this.side, this.pair);

  final _Side side;
  final MatchPair pair;

  bool same(_Side side, MatchPair pair) =>
      this.side == side && this.pair.id == pair.id;
}

/// Two shuffled columns to pair up, checked pair by pair, so there is no
/// «تحقق»: a right pair stays, a wrong one shakes and goes back, and the last
/// pair ends the question. The picks and flashes only draw this question, so
/// they stay here; only what the attempt needs goes up.
class MatchingBody extends StatefulWidget {
  const MatchingBody({required this.exercise, required this.answer, super.key});

  final MatchingExercise exercise;
  final BodyAnswer answer;

  @override
  State<MatchingBody> createState() => _MatchingBodyState();
}

class _MatchingBodyState extends State<MatchingBody> {
  _Pick? _picked;
  List<_Pick> _wrong = const [];
  final _locked = <String>{};

  /// Counts wrong pairs per card, so each one shakes again.
  final _shakes = <String, int>{};
  String _said = '';
  final _timers = <Timer>[];
  Timer? _wrongTimer;

  PairsDraft get _draft => switch (widget.answer.draft) {
    final PairsDraft draft => draft,
    _ => PairsDraft(total: widget.exercise.pairs.length),
  };

  @override
  void initState() {
    super.initState();
    if (widget.answer.evaluation != null) {
      _locked.addAll(_draft.matched);
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _wrongTimer?.cancel();
    super.dispose();
  }

  void _tap(_Side side, MatchPair pair) {
    final draft = _draft;
    if (draft.matched.contains(pair.id)) return;
    final picked = _picked;
    if (picked == null || picked.side == side) {
      AppHaptics.selectionClick();
      playSound(AppSound.tap);
      setState(() {
        _picked = picked != null && picked.same(side, pair)
            ? null
            : _Pick(side, pair);
        _wrong = const [];
      });
      return;
    }
    picked.pair.id == pair.id
        ? _matched(draft, pair)
        : _mismatched(draft, picked, _Pick(side, pair));
  }

  void _matched(PairsDraft draft, MatchPair pair) {
    AppHaptics.lightImpact();
    playSound(AppSound.correct);
    final next = PairsDraft(
      total: draft.total,
      matched: {...draft.matched, pair.id},
      mistakes: draft.mistakes,
    );
    setState(() {
      _picked = null;
      _wrong = const [];
      _said = 'lesson_pair_right'.tr(namedArgs: {'word': pair.id});
    });
    widget.answer.onDraft(next);
    _timers.add(
      Timer(AppMotion.pairLock, () {
        if (mounted) setState(() => _locked.add(pair.id));
      }),
    );
    if (next.isComplete) {
      _timers.add(Timer(AppMotion.pairsDone, widget.answer.onSubmit));
    }
  }

  void _mismatched(PairsDraft draft, _Pick first, _Pick second) {
    AppHaptics.mediumImpact();
    // The first mistake of a pair counts, and only the first (S §7.3).
    widget.answer.onDraft(
      PairsDraft(
        total: draft.total,
        matched: draft.matched,
        mistakes: {...draft.mistakes, first.pair.id},
      ),
    );
    setState(() {
      _picked = null;
      _wrong = [first, second];
      _said = 'lesson_pair_wrong'.tr();
      for (final pick in _wrong) {
        _shakes.update(_keyOf(pick), (n) => n + 1, ifAbsent: () => 1);
      }
    });
    _wrongTimer?.cancel();
    _wrongTimer = Timer(AppMotion.pairWrongHold, () {
      if (mounted) setState(() => _wrong = const []);
    });
  }

  String _keyOf(_Pick pick) => '${pick.side.name}:${pick.pair.id}';

  AnswerLook _lookOf(_Side side, MatchPair pair) {
    if (_draft.matched.contains(pair.id)) return AnswerLook.correct;
    if (_wrong.any((pick) => pick.same(side, pair))) return AnswerLook.wrong;
    return _picked?.same(side, pair) ?? false
        ? AnswerLook.selected
        : AnswerLook.idle;
  }

  Widget _card(_Side side, MatchPair pair) {
    final look = _lookOf(side, pair);
    final matched = look == AnswerLook.correct;
    final picture = side == _Side.meaning && pair.image.isNotEmpty;
    return _MatchCard(
      look: look,
      locked: _locked.contains(pair.id),
      shake: _shakes[_keyOf(_Pick(side, pair))] ?? 0,
      semanticLabel: switch (side) {
        _Side.word => pair.id,
        _Side.meaning when picture => 'lesson_picture_named'.tr(
          namedArgs: {'name': pair.alt},
        ),
        _Side.meaning => pair.meaning,
      },
      onTap: matched ? null : () => _tap(side, pair),
      child: switch (side) {
        _Side.word => _Label(pair.id, english: true),
        _Side.meaning when picture => _MatchPicture(url: pair.image),
        _Side.meaning => _Label(pair.meaning, english: false),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: _said,
          child: const SizedBox.shrink(),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Column(
                label: exercise.pictures
                    ? 'lesson_pictures'.tr()
                    : 'lesson_meanings'.tr(),
                children: [
                  for (final pair in exercise.meaningsShown)
                    _card(_Side.meaning, pair),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: _Column(
                  label: 'lesson_english_words'.tr(),
                  children: [
                    for (final pair in exercise.wordsShown)
                      _card(_Side.word, pair),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          child,
        ],
      ],
    ),
  );
}

/// A card of a pair. A right pair shows its check and then fades out of the way.
class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.look,
    required this.locked,
    required this.shake,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final AnswerLook look;
  final bool locked;
  final int shake;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  static const _height = 56.0;
  static const _checkInset = 10.0;
  static const _checkSize = 18.0;
  static const _lockedOpacity = .4;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: locked ? _lockedOpacity : 1,
    duration: AppMotion.resolve(context, AppMotion.fast),
    curve: AppMotion.out,
    child: AnswerCard(
      look: look,
      radius: AppRadius.md,
      shake: shake,
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: SizedBox(
        height: _height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            child,
            if (look == AnswerLook.correct)
              const PositionedDirectional(
                start: _checkInset,
                child: ChoiceCheck(
                  selected: true,
                  mark: ChoiceMark.correct,
                  showRing: false,
                  size: _checkSize,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.english});

  final String text;
  final bool english;

  static const _sideRoom = 32.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: _sideRoom),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        locale: english ? const Locale('en') : null,
        textDirection: english ? TextDirection.ltr : null,
        maxLines: 1,
        style: context.texts.body.copyWith(color: context.colors.textPrimary),
      ),
    ),
  );
}

class _MatchPicture extends StatelessWidget {
  const _MatchPicture({required this.url});

  final String url;

  static const _size = 48.0;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _size,
    child: LessonPicture(url: url),
  );
}
