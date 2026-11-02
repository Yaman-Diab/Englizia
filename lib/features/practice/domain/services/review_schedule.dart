import 'package:englizia/features/practice/domain/entities/word_bank.dart';

/// The boxes' waits in days: «عرفتها» moves a word to the next, «لم أعرفها»
/// back to the first, and the last box comes back every 30 days (S §10.2).
const boxDays = [1, 3, 7, 14, 30];

const boxCount = 5;

DateTime _startOfDay(DateTime at) => DateTime(at.year, at.month, at.day);

/// Due by [now]: on its day or after it.
bool isDue(BankWord word, DateTime now) => !word.dueAt.isAfter(now);

/// Where an answer leaves the word, counted from today. The server does the same
/// with the track's day start, and its answer replaces this one.
BankWord answered(BankWord word, {required bool known, required DateTime now}) {
  final box = known ? (word.box + 1).clamp(1, boxCount) : 1;
  return word.copyWith(
    box: box,
    dueAt: _startOfDay(now).add(Duration(days: boxDays[box - 1])),
  );
}

/// What a review takes: the words due, the longest waiting first; or, asked for
/// with none due, those coming soonest.
List<BankWord> sessionWords(WordBank bank, DateTime now) {
  final due = [
    for (final word in bank.words)
      if (isDue(word, now)) word,
  ];
  final pool = due.isNotEmpty ? due : [...bank.words];
  pool.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return pool.take(bank.sessionSize).toList();
}

/// How many words sit in each box, the first box first.
List<int> boxCounts(WordBank bank) {
  final counts = List.filled(boxCount, 0);
  for (final word in bank.words) {
    counts[word.box.clamp(1, boxCount) - 1]++;
  }
  return counts;
}

/// «تتعلّمها»: the first two boxes; «ثابتة»: the rest (S §10.4).
bool isLearning(BankWord word) => word.box <= 2;
