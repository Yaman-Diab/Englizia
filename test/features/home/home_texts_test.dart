import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/pump_app.dart';

/// The texts home builds come out as the design prints them.
void main() {
  setUpAll(initLocalizationForTests);

  testWidgets('Arabic, word for word', (tester) async {
    await tester.pumpLocalized(const SizedBox());

    expect(riskText(5, 7), '5 دقائق تحافظ على أيامك السبعة');
    expect(
      statusText((kind: HomeStatusKind.minutesLeft, minutesLeft: 3)),
      '3 دقائق وتحقق هدف اليوم',
    );
    expect(
      'home_head_semantics'.tr(
        namedArgs: {
          'greeting': greetingText(HomeGreeting.evening, 'أحمد', spoken: true),
          'today': 'home_today_minutes'.plural(10, namedArgs: {'min': '7'}),
          'streak': 'me_streak_count'.plural(7),
        },
      ),
      'مساء الخير أحمد. 7 من 10 دقائق اليوم. 7 أيام متتالية.',
    );
    expect(
      'home_flame_semantics'.tr(
        namedArgs: {
          'days': 'me_streak_count'.plural(7),
          'have': '2',
          'max': '3',
        },
      ),
      '7 أيام متتالية، رصيد التجميد 2 من 3. افتح التفاصيل',
    );
    expect(
      'home_freeze_sub'.tr(
        namedArgs: {
          'left': 'home_freeze_left'.plural(1, namedArgs: {'max': '3'}),
          'weekly': 'home_freeze_weekly'.plural(1),
        },
      ),
      'بقي تجميد واحد من 3. يُضاف واحد كل أسبوع.',
    );
    expect(
      'home_broke_sub'.tr(args: [daysText(7)]),
      'وصلت إلى 7 أيام، ولم يبقَ تجميد. درس واحد اليوم يبدأ سلسلة جديدة.',
    );
    expect(
      'home_test_body'.plural(15, namedArgs: {'min': '12'}),
      '12 إلى 15 دقيقة لتبدأ من المستوى المناسب',
    );
    expect(
      'home_units_count'.plural(8, namedArgs: {'done': '2'}),
      '2 من 8 وحدات',
    );
    expect('unit_progress'.plural(6, namedArgs: {'done': '3'}), '3 من 6 دروس');
    expect(
      reviewLine(const HomeReview(wordsDue: 12, conceptsDue: 3, minutes: 5)),
      '12 كلمة و3 مفاهيم، نحو 5 دقائق',
    );
    final market = mockHome().units[3].preview!;
    expect(
      'home_preview_meta'.tr(
        namedArgs: {
          'lessons': 'home_lessons'.plural(market.lessons.length),
          'minutes': minutesText(market.roundedMinutes),
        },
      ),
      '6 دروس · نحو 40 دقيقة',
    );
    expect(
      'home_kid_head_semantics'.tr(
        namedArgs: {
          'name': 'ليان',
          'days': 'me_streak_count'.plural(4),
          'stars': 'unit_kid_stars'.plural(14),
        },
      ),
      'أهلًا ليان. 4 أيام متتالية. 14 نجمة.',
    );
  });

  testWidgets('Arabic, the helpers', (tester) async {
    await tester.pumpLocalized(const SizedBox());

    expect(yourDays(1), 'يومك');
    expect(yourDays(2), 'يوميك');
    expect(yourDays(3), 'أيامك الثلاثة');
    expect(yourDays(10), 'أيامك العشرة');
    expect(yourDays(12), 'أيامك الـ12');
    expect(daysText(1), 'يوم واحد');
    expect(daysText(11), '11 يومًا');

    final home = mockHome();
    expect(levelTitle(home), 'A2، ما قبل المتوسط');
    expect(levelTitle(mockHome(emar: true)), 'الصف السابع');
    expect(levelTitle(mockHome(kids: true)), 'Starter 2، المواضيع');
    expect(unitTitle(home.units[2]), 'الوحدة 3 · يوم في المزرعة');

    final lessons = home.currentUnit!.lessons;
    expect(lessons.map(kindShort), [
      'مفردات',
      'فيديو',
      'قواعد',
      'نص',
      'محادثة',
      'مراجعة الوحدة',
    ]);
    expect(lessonMeta(lessons[4]), 'محادثة ذكية، 5 دقائق');
    expect(lessonMeta(lessons[2]), 'فيديو قواعد، 8 دقائق');
    expect(lessonMeta(lessons[5]), 'اختبار، 10 دقائق');
    final gate = mockHome(
      scenario: HomeMockScenario.firstDay,
    ).currentUnit!.lessons.last;
    expect(kindShort(gate), 'فحص المستوى');

    expect(
      reviewLine(const HomeReview(wordsDue: 12, minutes: 5)),
      '12 كلمة، نحو 5 دقائق',
    );
    expect(
      reviewLine(const HomeReview(wordsDue: 0, conceptsDue: 3, minutes: 5)),
      '3 مفاهيم، نحو 5 دقائق',
    );

    expect(greetingText(HomeGreeting.morning, 'أحمد'), 'صباح الخير، أحمد');
    expect(greetingText(HomeGreeting.back, 'أحمد'), 'أهلًا بعودتك يا أحمد');
    expect(greetingText(HomeGreeting.firstDay, 'أحمد'), 'أهلًا أحمد');
    expect(greetingText(HomeGreeting.kids, 'ليان'), 'أهلًا ليان!');
    expect(
      statusText((kind: HomeStatusKind.goalReached, minutesLeft: 0)),
      'حققت هدف اليوم',
    );
  });

  testWidgets('English reads as English', (tester) async {
    await tester.pumpLocalized(const SizedBox(), locale: AppLocales.english);

    expect(riskText(5, 7), '5 minutes keep your seven days');
    expect(riskText(1, 12), '1 minute keep your 12 days');
    expect(
      statusText((kind: HomeStatusKind.minutesLeft, minutesLeft: 3)),
      "3 minutes to reach today's goal",
    );
    expect(
      reviewLine(const HomeReview(wordsDue: 12, conceptsDue: 3, minutes: 5)),
      '12 words and 3 concepts, about 5 minutes',
    );
    expect(levelTitle(mockHome()), 'A2, ما قبل المتوسط');
    expect(greetingText(HomeGreeting.evening, 'Sam'), 'Good evening, Sam');
    expect(
      'home_units_count'.plural(8, namedArgs: {'done': '2'}),
      '2 of 8 units',
    );
  });
}
