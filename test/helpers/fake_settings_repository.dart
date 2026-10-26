import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';

/// The contract's example (`assets/mock/settings/effective.json`) as entities.
const testSettings = EffectiveSettings(
  reminder: ReminderSettings(
    presets: [
      ReminderPreset(slot: ReminderSlot.morning, time: ReminderTime(8, 0)),
      ReminderPreset(slot: ReminderSlot.noon, time: ReminderTime(13, 0)),
      ReminderPreset(slot: ReminderSlot.evening, time: ReminderTime(20, 0)),
    ],
    defaultSlot: ReminderSlot.evening,
    title: LocalizedText(
      ar: 'حان وقت درسك اليومي',
      en: 'Time for your daily lesson',
    ),
    body: LocalizedText(
      ar: '{minutes} دقائق فقط وتحافظ على أيامك المتتالية',
      en: 'Just {minutes} minutes keeps your streak going',
    ),
  ),
  dailyGoal: DailyGoalSettings(
    options: [
      DailyGoalOption(
        minutes: 5,
        label: LocalizedText(ar: 'مريح', en: 'Easy'),
      ),
      DailyGoalOption(
        minutes: 10,
        label: LocalizedText(ar: 'قياسي', en: 'Standard'),
      ),
      DailyGoalOption(
        minutes: 15,
        label: LocalizedText(ar: 'جاد', en: 'Serious'),
      ),
      DailyGoalOption(
        minutes: 20,
        label: LocalizedText(ar: 'مكثّف', en: 'Intensive'),
      ),
    ],
    defaultMinutes: 10,
    lessonMinutes: 10,
  ),
);

/// Serves queued results in order, repeating the last one.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([
    this.results = const [Ok<EffectiveSettings>(testSettings)],
  ]);

  final List<Result<EffectiveSettings>> results;
  var calls = 0;

  @override
  Future<Result<EffectiveSettings>> getSettings() async =>
      results[(calls++).clamp(0, results.length - 1)];
}
