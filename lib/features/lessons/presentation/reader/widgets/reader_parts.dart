import 'dart:async';

import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/reader_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_card.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_sentence.dart';
import 'package:englizia/features/lessons/presentation/video/player_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Carries the time on between the media's reports, frame by frame while it plays,
/// and stops it when the app is left: a call or going away stops it (S §8.1).
class ReaderClock extends StatefulWidget {
  const ReaderClock({required this.cubit, required this.child, super.key});

  final ReaderCubit cubit;
  final Widget child;

  @override
  State<ReaderClock> createState() => _ReaderClockState();
}

class _ReaderClockState extends State<ReaderClock>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  var _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onFrame);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && widget.cubit.state.playing) {
      unawaited(widget.cubit.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    final delta = elapsed - _lastFrame;
    _lastFrame = elapsed;
    widget.cubit.tick(delta);
  }

  void _followPlaying(bool playing) {
    if (playing && !_ticker.isActive) {
      _lastFrame = Duration.zero;
      unawaited(_ticker.start());
    } else if (!playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<ReaderCubit, ReaderState>(
    bloc: widget.cubit,
    listenWhen: (before, now) => before.playing != now.playing,
    listener: (_, state) => _followPlaying(state.playing),
    child: widget.child,
  );
}

/// A sentence's values, so that moving from word to word redraws one sentence only.
SentenceView readerSentenceView(
  ReaderState state,
  int index, {
  required bool video,
  bool? translationOpen,
}) {
  final sentence = state.content!.sentences[index];
  final playingVideo = video && state.stage != VideoStage.cover;
  final current = state.current == index && (!video || playingVideo);
  final said = current && state.started ? state.word : null;
  final selection = state.selection?.sentence == index ? state.selection : null;
  return SentenceView(
    current: current,
    dim: playingVideo && !current,
    saidWord: selection == null ? said : null,
    saidFor: said == null
        ? Duration.zero
        : (sentence.words[said].end - sentence.words[said].start) *
              (1 / state.speed),
    // A video's translation shows unless it was closed; a text's once it is opened.
    open: state.open.contains(index) != video,
    revealed: state.revealed.contains(index),
    selection: selection,
    mode: video ? state.prefs.videoMode : state.prefs.mode,
    size: state.prefs.size,
  );
}

/// The sentences one under the other, each following only its own values.
class ReaderSentences extends StatelessWidget {
  const ReaderSentences({
    required this.cubit,
    required this.content,
    required this.keys,
    required this.gap,
    required this.onListen,
    this.video = false,
    super.key,
  });

  final ReaderCubit cubit;
  final ReaderContent content;
  final ReaderKeys keys;
  final double gap;
  final ValueChanged<int> onListen;
  final bool video;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, sentence) in content.sentences.indexed) ...[
        if (i > 0) SizedBox(height: gap),
        BlocSelector<ReaderCubit, ReaderState, SentenceView>(
          bloc: cubit,
          selector: (state) => readerSentenceView(state, i, video: video),
          builder: (context, view) => ReaderSentenceBlock(
            index: i,
            sentence: sentence,
            content: content,
            view: view,
            keys: keys,
            video: video,
            onTapSentence: () => cubit.goTo(i),
            onTapWord: (word) {
              if (!cubit.selectWord(i, word)) cubit.goTo(i);
              return true;
            },
            onListen: () => onListen(i),
            onToggleTranslation: () => cubit.toggleTranslation(i),
            onReveal: () => cubit.reveal(i),
          ),
        ),
      ],
    ],
  );
}

/// A pressed word's card over the [areaKey] it is measured in, and closing it by
/// pressing anywhere else.
class ReaderCardLayer extends StatefulWidget {
  const ReaderCardLayer({
    required this.cubit,
    required this.keys,
    required this.areaKey,
    super.key,
  });

  final ReaderCubit cubit;
  final ReaderKeys keys;
  final GlobalKey areaKey;

  @override
  State<ReaderCardLayer> createState() => _ReaderCardLayerState();
}

class _ReaderCardLayerState extends State<ReaderCardLayer> {
  Rect? _anchor;
  Size? _areaSize;

  /// Where the card should point: over the whole span when it shares a line.
  void _place(ReaderSelection selection) {
    final area = widget.areaKey.currentContext?.findRenderObject();
    if (area is! RenderBox) return;
    final sentence = widget.cubit.state.content!.sentences[selection.sentence];
    final span = selection.span;
    Rect? rect;
    for (final (i, word) in sentence.words.indexed) {
      if (!(span?.wordIds.contains(word.id) ?? i == selection.word)) continue;
      final box = widget.keys
          .word(selection.sentence, i)
          .currentContext
          ?.findRenderObject();
      if (box is! RenderBox) continue;
      final here = box.localToGlobal(Offset.zero, ancestor: area) & box.size;
      rect = rect == null || (rect.top - here.top).abs() > 4
          ? rect ?? here
          : rect.expandToInclude(here);
    }
    setState(() {
      _anchor = rect;
      _areaSize = area.size;
    });
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ReaderCubit, ReaderState>(
    bloc: widget.cubit,
    listenWhen: (before, now) => before.selection != now.selection,
    listener: (_, state) {
      if (state.selection case final selection?) _place(selection);
    },
    buildWhen: (before, now) =>
        before.selection != now.selection || before.saved != now.saved,
    builder: (context, state) {
      final selection = state.selection;
      final anchor = _anchor;
      final size = _areaSize;
      if (selection == null || anchor == null || size == null) {
        return const SizedBox.shrink();
      }
      final word =
          state.content!.sentences[selection.sentence].words[selection.word];
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.cubit.closeCard,
          ),
          ReaderCard(
            span: selection.span,
            word: word.text,
            gloss: word.gloss,
            anchor: anchor,
            area: size,
            saved: state.saved.contains(selection.span?.id),
            onSay: widget.cubit.sayCard,
            onSave: widget.cubit.toggleSaved,
          ),
        ],
      );
    },
  );
}
