/// [text] as compared: no case, punctuation or extra spaces (S §7.4).
String plainWords(String text) => text
    .toLowerCase()
    .replaceAll('\u2019', "'")
    .replaceAll(RegExp("[^a-z0-9' ]+"), ' ')
    .replaceAll(RegExp(' +'), ' ')
    .trim();

final _space = RegExp(r'\s+', unicode: true);
final _punctuation = RegExp(r'\p{P}', unicode: true);

/// The words of [texts] as an order of words is compared, the server's rule
/// R45 (docs/api/lessons.md): each text split at its spaces, with no
/// punctuation or case, and nothing for what that leaves empty. "have to" is
/// two words, and "It's" is "its".
List<String> orderWords(Iterable<String> texts) => [
  for (final text in texts)
    for (final part in text.split(_space))
      if (part.replaceAll(_punctuation, '').toLowerCase() case final word
          when word.isNotEmpty)
        word,
];

/// Which of [words] are in [transcript], each as many times as it was said, in
/// any order: the engine catches words, not a reading (S §2).
List<bool> heardWords(List<String> words, String transcript) {
  final said = plainWords(transcript).split(' ');
  return [for (final word in words) said.remove(plainWords(word))];
}
