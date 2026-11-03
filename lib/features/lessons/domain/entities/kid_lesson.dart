import 'package:equatable/equatable.dart';

/// A word with its picture and voice, as a child sees it.
final class KidWord extends Equatable {
  const KidWord({
    required this.word,
    required this.image,
    this.arabic = '',
    this.audioUrl,
  });

  final String word;
  final String image;

  /// Its Arabic name, for screen readers.
  final String arabic;
  final String? audioUrl;

  @override
  List<Object?> get props => [word, image, arabic, audioUrl];
}

/// A screen of a kids' lesson (requirements v3.0 §13.2, design "Kid Lesson"),
/// each with its Arabic instruction, recorded, played by itself.
sealed class KidStep extends Equatable {
  const KidStep({required this.id, this.instructionAudioUrl});

  final String id;
  final String? instructionAudioUrl;
}

/// «بطاقة الكلمة» (Starter 2): a big picture, the word, its voice.
final class KidWordStep extends KidStep {
  const KidWordStep({
    required super.id,
    required this.word,
    super.instructionAudioUrl,
  });

  final KidWord word;

  @override
  List<Object?> get props => [id, instructionAudioUrl, word];
}

/// «بطاقة الحرف» (Starter 1): the letter's video, the letter in both cases with
/// its voice, and two words that start with it.
final class KidLetterStep extends KidStep {
  const KidLetterStep({
    required super.id,
    required this.letter,
    required this.words,
    super.instructionAudioUrl,
    this.videoUrl,
    this.videoLength,
    this.audioUrl,
  });

  /// The capital; the small one is shown beside it.
  final String letter;
  final List<KidWord> words;
  final String? videoUrl;

  /// How long the video runs, when the player can't tell.
  final Duration? videoLength;
  final String? audioUrl;

  @override
  List<Object?> get props => [
    id,
    instructionAudioUrl,
    letter,
    words,
    videoUrl,
    videoLength,
    audioUrl,
  ];
}

/// One of the lesson's questions, answered by pressing: listening for a letter
/// or a picture, or matching pictures with their words.
final class KidQuestionStep extends KidStep {
  const KidQuestionStep({required super.id, super.instructionAudioUrl});

  @override
  List<Object?> get props => [id, instructionAudioUrl];
}

/// What the guide says between the screens, recorded once.
final class KidVoice extends Equatable {
  const KidVoice({this.praise, this.tryAgain, this.leave, this.done});

  /// «أحسنت!», «حاول مرة أخرى», «تريد أن تخرج؟» and the lesson's end:
  /// «رائع! تعلّمت ست كلمات جديدة».
  final String? praise;
  final String? tryAgain;
  final String? leave;
  final String? done;

  @override
  List<Object?> get props => [praise, tryAgain, leave, done];
}

/// A kids' lesson: its screens in order, the words it teaches, and the guide's
/// voice.
final class KidLesson extends Equatable {
  const KidLesson({
    required this.steps,
    required this.words,
    this.voice = const KidVoice(),
  });

  final List<KidStep> steps;
  final List<KidWord> words;
  final KidVoice voice;

  @override
  List<Object?> get props => [steps, words, voice];
}
