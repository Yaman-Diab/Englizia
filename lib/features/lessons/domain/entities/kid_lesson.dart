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

/// A recorded line in English.
final class KidLine extends Equatable {
  const KidLine({required this.text, this.audioUrl});

  final String text;
  final String? audioUrl;

  @override
  List<Object?> get props => [text, audioUrl];
}

/// A word of a sung or told sentence, and when its sound says it.
final class KidTimedWord extends Equatable {
  const KidTimedWord(this.text, this.start);

  final String text;
  final Duration start;

  @override
  List<Object?> get props => [text, start];
}

/// A page of a picture story: one sentence, told with its words marked as
/// they are said, from the timings in its sound.
final class KidStoryPage extends Equatable {
  const KidStoryPage({
    required this.image,
    required this.words,
    this.audioUrl,
    this.marked = const [],
  });

  final String image;
  final List<KidTimedWord> words;
  final String? audioUrl;

  /// The words that open a little card with their picture and voice.
  final List<KidWord> marked;

  String get sentence => words.map((word) => word.text).join(' ');

  /// The card [text] opens, if it is marked.
  KidWord? markedFor(String text) {
    final plain = text.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    return marked.where((word) => word.word == plain).firstOrNull;
  }

  @override
  List<Object?> get props => [image, words, audioUrl, marked];
}

/// «قصة مصوّرة» (S §13.3): a page for each sentence, 3 to 6 of them.
final class KidStoryStep extends KidStep {
  const KidStoryStep({
    required super.id,
    required this.pages,
    super.instructionAudioUrl,
  });

  final List<KidStoryPage> pages;

  @override
  List<Object?> get props => [id, instructionAudioUrl, pages];
}

/// «أنشودة» (S §13.3): its video, slower by default, and its lines with the
/// one sung marked, without a translation.
final class KidSongStep extends KidStep {
  const KidSongStep({
    required super.id,
    required this.lines,
    super.instructionAudioUrl,
    this.videoUrl,
    this.videoLength,
    this.pictures = const [],
  });

  /// Each line's words, timed on the video.
  final List<List<KidTimedWord>> lines;
  final String? videoUrl;
  final Duration? videoLength;

  /// What shows in the video's place before it plays.
  final List<String> pictures;

  /// The panel's default (S §13.3), and the normal speed beside it.
  static const slow = .75;
  static const normal = 1.0;

  @override
  List<Object?> get props => [
    id,
    instructionAudioUrl,
    lines,
    videoUrl,
    videoLength,
    pictures,
  ];
}

/// A reply the child picks by its picture: the character answers it, then
/// the child says its sentence.
final class KidReply extends Equatable {
  const KidReply({
    required this.word,
    required this.answer,
    required this.echo,
  });

  final KidWord word;
  final KidLine answer;

  /// «ردّد»: what the child says next.
  final KidLine echo;

  @override
  List<Object?> get props => [word, answer, echo];
}

/// «حوار مكتوب» (S §13.3), always written ahead: the character asks, the child
/// picks a picture, repeats the sentence, and the character says goodbye.
final class KidDialogueStep extends KidStep {
  const KidDialogueStep({
    required super.id,
    required this.character,
    required this.opening,
    required this.replies,
    required this.closing,
    super.instructionAudioUrl,
    this.echoInstructionAudioUrl,
  });

  /// Its name and picture.
  final KidWord character;
  final KidLine opening;
  final List<KidReply> replies;
  final KidLine closing;

  /// «قل الجملة», before the child repeats.
  final String? echoInstructionAudioUrl;

  @override
  List<Object?> get props => [
    id,
    instructionAudioUrl,
    character,
    opening,
    replies,
    closing,
    echoInstructionAudioUrl,
  ];
}

/// «كرّر بعدي» (S §13.3): a word to hear and say. The try itself earns the
/// star, with no words missed or numbers.
final class KidSpeakStep extends KidStep {
  const KidSpeakStep({
    required super.id,
    required this.word,
    super.instructionAudioUrl,
  });

  final KidWord word;

  @override
  List<Object?> get props => [id, instructionAudioUrl, word];
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
