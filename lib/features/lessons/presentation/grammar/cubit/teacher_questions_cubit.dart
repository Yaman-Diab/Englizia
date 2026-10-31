import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';
import 'package:englizia/features/lessons/domain/repositories/teacher_question_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class TeacherQuestionsState extends Equatable {
  const TeacherQuestionsState({
    this.load = LoadStatus.loading,
    this.failure,
    this.questions = const [],
  });

  final LoadStatus load;
  final Failure? failure;

  /// The learner's own, newest first.
  final List<TeacherQuestion> questions;

  TeacherQuestionsState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    List<TeacherQuestion>? questions,
  }) => TeacherQuestionsState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    questions: questions ?? this.questions,
  );

  @override
  List<Object?> get props => [load, failure, questions];
}

/// A learner's private conversation with the teacher on a lesson (ADR 14). A
/// question shows at once; one that couldn't go stays, with a way to send it again.
class TeacherQuestionsCubit extends Cubit<TeacherQuestionsState> {
  TeacherQuestionsCubit(this._questions, {required this.lessonId})
    : super(const TeacherQuestionsState());

  final TeacherQuestionRepository _questions;
  final String lessonId;

  Future<void> load() async {
    emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    final result = await _questions.list(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(load: LoadStatus.ready, questions: value));
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  Future<void> ask(String text, {Duration? videoPosition}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final question = TeacherQuestion(
      id: _questions.newQuestionId(),
      text: trimmed,
      askedAt: DateTime.now(),
      videoPosition: videoPosition,
      status: QuestionStatus.sending,
    );
    emit(state.copyWith(questions: [question, ...state.questions]));
    await _send(question);
  }

  /// «أعد الإرسال», under the same id.
  Future<void> resend(TeacherQuestion question) async {
    final sending = question.withStatus(QuestionStatus.sending);
    _replace(sending);
    await _send(sending);
  }

  Future<void> _send(TeacherQuestion question) async {
    final result = await _questions.ask(lessonId, question);
    if (isClosed) return;
    _replace(switch (result) {
      Ok(:final value) => value,
      Err() => question.withStatus(QuestionStatus.failed),
    });
  }

  void _replace(TeacherQuestion question) => emit(
    state.copyWith(
      questions: [
        for (final other in state.questions)
          other.id == question.id ? question : other,
      ],
    ),
  );
}
