/// [text] as compared: no case, punctuation or extra spaces (S §7.4).
String plainWords(String text) => text
    .toLowerCase()
    .replaceAll('\u2019', "'")
    .replaceAll(RegExp("[^a-z0-9' ]+"), ' ')
    .replaceAll(RegExp(' +'), ' ')
    .trim();

/// Which of [words] are in [transcript], each as many times as it was said, in
/// any order: the engine catches words, not a reading (S §2).
List<bool> heardWords(List<String> words, String transcript) {
  final said = plainWords(transcript).split(' ');
  return [for (final word in words) said.remove(plainWords(word))];
}
