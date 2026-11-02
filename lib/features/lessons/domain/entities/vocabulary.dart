import 'package:equatable/equatable.dart';

/// What kind of word a card teaches (S §8.5). An unknown kind shows no badge.
enum VocabKind { noun, verb, adjective, adverb, phrase }

/// A word of the example, its punctuation stuck to it, and when it is said in the
/// example's sound, if the server knows.
final class VocabToken extends Equatable {
  const VocabToken({
    required this.id,
    required this.text,
    this.start,
    this.end,
  });

  final String id;
  final String text;
  final Duration? start;
  final Duration? end;

  @override
  List<Object?> get props => [id, text, start, end];
}

/// The word used in a sentence, with the words that are it marked.
final class VocabExample extends Equatable {
  const VocabExample({
    required this.tokens,
    required this.arabic,
    this.highlighted = const {},
    this.audioUrl,
  });

  final List<VocabToken> tokens;
  final String arabic;

  /// Ids of the tokens that are the word: one, or a phrase's several.
  final Set<String> highlighted;
  final String? audioUrl;

  String get english => tokens.map((token) => token.text).join(' ');

  /// The token said at [at] of a sound [length] long: by the tokens' own times,
  /// or else shared out by their letters.
  int? tokenAt(Duration at, Duration length) {
    if (tokens.isEmpty || at >= length) return null;
    if (tokens.every((token) => token.start != null)) {
      int? said;
      for (final (i, token) in tokens.indexed) {
        if (at >= token.start!) said = i;
      }
      return said;
    }
    final letters = tokens.fold<int>(
      0,
      (sum, token) => sum + token.text.length,
    );
    var passed = 0;
    for (final (i, token) in tokens.indexed) {
      passed += token.text.length;
      if (at.inMicroseconds * letters < length.inMicroseconds * passed) {
        return i;
      }
    }
    return tokens.length - 1;
  }

  @override
  List<Object?> get props => [tokens, arabic, highlighted, audioUrl];
}

/// One card of a vocabulary lesson.
final class VocabWord extends Equatable {
  const VocabWord({
    required this.id,
    required this.word,
    required this.arabic,
    required this.example,
    this.kind,
    this.imageUrl,
    this.audioUrl,
  });

  final String id;
  final String word;
  final VocabKind? kind;
  final String arabic;

  /// With none, the card shows the word's first letter.
  final String? imageUrl;
  final String? audioUrl;
  final VocabExample example;

  @override
  List<Object?> get props => [
    id,
    word,
    kind,
    arabic,
    imageUrl,
    audioUrl,
    example,
  ];
}

/// The cards of a vocabulary lesson, browsed before its exercises (S §8.5).
final class VocabContent extends Equatable {
  const VocabContent({required this.words});

  final List<VocabWord> words;

  @override
  List<Object?> get props => [words];
}
