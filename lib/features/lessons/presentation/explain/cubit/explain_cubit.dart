import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';
import 'package:englizia/features/lessons/domain/repositories/explain_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ExplainStatus {
  /// «نكتب لك الشرح…».
  loading,
  ready,

  /// «تعذّر الشرح الآن»: not counted, and it can be asked again.
  failed,

  /// None left today: the AI isn't asked.
  quotaOut,
}

final class ExplainState extends Equatable {
  const ExplainState({
    this.status = ExplainStatus.loading,
    this.explanation,
    this.left,
    this.fresh = true,
    this.helpful,
  });

  final ExplainStatus status;
  final Explanation? explanation;

  /// The explanations left today, when known.
  final int? left;

  /// Written just now, so it arrives with its motion; one opened again is
  /// simply there.
  final bool fresh;

  /// The thumbs, once given; they can't change.
  final bool? helpful;

  ExplainState copyWith({
    ExplainStatus? status,
    Explanation? explanation,
    int? Function()? left,
    bool? fresh,
    bool? helpful,
  }) => ExplainState(
    status: status ?? this.status,
    explanation: explanation ?? this.explanation,
    left: left != null ? left() : this.left,
    fresh: fresh ?? this.fresh,
    helpful: helpful ?? this.helpful,
  );

  @override
  List<Object?> get props => [status, explanation, left, fresh, helpful];
}

/// «اشرح لي» (requirements v3.0 §7.2, design "Explain Me"): why this learner's
/// answer was wrong, made by the server's AI within the day's limit. Its own
/// small cubit, as the sheet opens over the feedback of any question.
class ExplainCubit extends Cubit<ExplainState> {
  ExplainCubit(this._explain, ClipPlayer player, {required this.request})
    : _playback = ClipPlayback(player),
      super(const ExplainState());

  final ExplainRepository _explain;
  final ClipPlayback _playback;
  final ExplainRequest request;

  Future<void> start() async {
    emit(state.copyWith(status: ExplainStatus.loading));
    final result = await _explain.explain(request);
    if (isClosed) return;
    switch (result) {
      case Ok(
        value: ExplainReady(:final explanation, :final left, :final fresh),
      ):
        emit(
          state.copyWith(
            status: ExplainStatus.ready,
            explanation: explanation,
            left: () => left,
            fresh: fresh,
          ),
        );
      case Ok(value: ExplainQuotaOut()):
        emit(state.copyWith(status: ExplainStatus.quotaOut, left: () => 0));
      case Err():
        emit(state.copyWith(status: ExplainStatus.failed));
    }
  }

  /// «إعادة المحاولة».
  Future<void> retry() async {
    if (state.status != ExplainStatus.failed) return;
    await start();
  }

  void rate({required bool helpful}) {
    final explanation = state.explanation;
    if (explanation == null || state.helpful != null) return;
    emit(state.copyWith(helpful: helpful));
    unawaited(_explain.rate(explanation.id, helpful: helpful));
  }

  /// «مثال آخر»'s voice.
  Future<void> playExample() async {
    final url = state.explanation?.exampleAudioUrl;
    if (url == null) return;
    await _playback.start(url, onEnd: () {});
  }

  @override
  Future<void> close() {
    _playback.stop();
    return super.close();
  }
}
