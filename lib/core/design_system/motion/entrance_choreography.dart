import 'package:englizia/core/design_system/motion/app_motion.dart';

/// When each element of a screen family starts its [Entrance], measured from
/// the screen's first frame. Values follow the designs' entrance notes; change
/// them here and every screen of the family follows.

/// Hero screens (welcome): logo down, guide pop, text and actions up.
abstract final class HeroEntrance {
  static const badge = Duration(milliseconds: 150);
  static const mascot = Duration(milliseconds: 270);
  static const title = Duration(milliseconds: 430);
  static const body = Duration(milliseconds: 530);
  static const actions = Duration(milliseconds: 650);

  /// When the last element has arrived.
  static Duration get settled => actions + AppMotion.entrance;
}

/// The splash (Splash Form): the stage settles, the guide hops in, a ring
/// ripples out and the name rises; then a state's content arrives.
abstract final class SplashIntro {
  static const stage = Duration(milliseconds: 250);
  static const guide = Duration(milliseconds: 350);
  static const rippleDelay = Duration(milliseconds: 330);
  static const ripple = Duration(milliseconds: 440);
  static const nameDelay = Duration(milliseconds: 350);
  static const name = Duration(milliseconds: 200);

  /// A state's text and actions (update, offline), after the intro.
  static const content = Duration(milliseconds: 250);
  static const actionsDelay = Duration(milliseconds: 100);

  /// «جاري التحميل…»: each dot hops in turn.
  static const dotsRound = Duration(milliseconds: 900);
  static const dotsStagger = Duration(milliseconds: 150);

  /// When the intro has played.
  static Duration get settled => rippleDelay + ripple;
}

/// Onboarding questions: guide and bubble pop, answers rise one by one, then
/// the helper and the continue button.
abstract final class QuestionEntrance {
  static const mascot = Duration(milliseconds: 120);
  static const bubble = Duration(milliseconds: 240);
  static const subtitle = Duration(milliseconds: 300);
  static const firstAnswer = Duration(milliseconds: 340);
  static const answerStagger = Duration(milliseconds: 60);
  static const helper = Duration(milliseconds: 540);
  static const action = Duration(milliseconds: 600);

  static Duration answer(int index) => firstAnswer + answerStagger * index;

  /// When the last element has arrived.
  static Duration get settled => action + AppMotion.entrance;
}

/// Form screens (account): the header, then each field, then the action.
abstract final class FormEntrance {
  static const header = Duration(milliseconds: 120);
  static const firstField = Duration(milliseconds: 200);
  static const fieldStagger = Duration(milliseconds: 80);
  static const action = Duration(milliseconds: 440);

  static Duration field(int index) => firstField + fieldStagger * index;
}

/// "Password changed" (design), one moment under a second and a half after
/// the page fades in: the badge grows, its check draws, the guide hops once,
/// then the action fades in.
abstract final class PasswordChangedEntrance {
  static const badge = Duration(milliseconds: 250);
  static const check = Duration(milliseconds: 500);
  static const hop = Duration(milliseconds: 800);
  static const action = Duration(milliseconds: 1100);
  static const actionFade = Duration(milliseconds: 200);

  /// When the last element has arrived.
  static Duration get settled => action + actionFade;
}

/// "Your email is confirmed" (design "Verify Email"): the card, then its badge
/// and check, then the guide hops once.
abstract final class EmailConfirmedEntrance {
  static const card = Duration(milliseconds: 200);
  static const badge = Duration(milliseconds: 120);
  static const check = Duration(milliseconds: 370);
  static const hop = Duration(milliseconds: 680);
}

/// The reminder to confirm the email comes a moment after home has loaded, not
/// with it (design "Verify Email").
abstract final class EmailReminderEntrance {
  static const delay = Duration(milliseconds: 700);
}

/// The placement result (design): the ladder's steps rise one by one, the
/// guide appears on the first and hops up to the level, sparks and the level
/// land together, then the rest and the skill bars. Under two seconds.
final class PlacementResultEntrance {
  const PlacementResultEntrance(this.level);

  /// The steps to climb from the first.
  final int level;

  static const stepStagger = Duration(milliseconds: 50);
  static const stepRise = Duration(milliseconds: 200);
  static const guide = Duration(milliseconds: 300);
  static const guideFade = AppMotion.quick;

  /// A hop takes [hopAir], then it rests until the next one.
  static const hop = Duration(milliseconds: 200);
  static const hopAir = Duration(milliseconds: 180);
  static const trailFade = Duration(milliseconds: 160);
  static const trailDelay = AppMotion.quick;
  static const sparkPop = Duration(milliseconds: 320);
  static const sparkStagger = Duration(milliseconds: 70);
  static const levelPop = AppMotion.fast;
  static const restDelay = Duration(milliseconds: 220);
  static const restFade = Duration(milliseconds: 260);
  static const barFill = AppMotion.slow;

  /// When the guide starts climbing.
  static Duration get climb => guide + guideFade;

  /// When the guide reaches [level].
  Duration get land => climb + hop * level;

  /// When the content under the ladder starts.
  Duration get rest => land + restDelay;

  /// When everything has arrived.
  Duration get settled => rest + barFill;
}

/// Lowering the level, once the sheet has closed: one hop down, then the level.
abstract final class PlacementLowerEntrance {
  static const hop = Duration(milliseconds: 260);
  static const level = Duration(milliseconds: 440);
  static const settled = Duration(milliseconds: 690);
}

/// The mail scene (design "Check Email"): the envelope lands at once, then
/// the letter slides up, then the guide peeks out.
abstract final class MailSceneEntrance {
  static const letter = Duration(milliseconds: 380);
  static const guide = Duration(milliseconds: 580);
}

/// The verdict on the feedback sheet, once the sheet is on its way up: the
/// circle, its stroke, then what the answer earned.
abstract final class FeedbackEntrance {
  static const circle = Duration(milliseconds: 120);
  static const stroke = Duration(milliseconds: 270);
  static const reward = Duration(milliseconds: 520);
}

/// A conversation's lines, one after the other.
abstract final class DialogueEntrance {
  static const first = Duration(milliseconds: 160);
  static const stagger = Duration(milliseconds: 150);

  static Duration line(int index) => first + stagger * index;
}

/// The learner's words arriving in their bubble, then the judging.
abstract final class SpokenEntrance {
  static const first = Duration(milliseconds: 120);
  static const stagger = Duration(milliseconds: 80);
  static const toCheck = Duration(milliseconds: 300);

  static Duration word(int index) => first + stagger * index;

  /// When the last of [words] has had its turn and the judging can start.
  static Duration settled(int words) => word(words) + toCheck;
}

/// The end of a lesson, under two seconds: the circle, the guide's hop, the badge
/// and its check, the title, the rest, and then the chain. What comes from the
/// server starts at [xp] or when it arrives, whichever is later, and goes by the
/// `*AfterData` steps from there.
abstract final class LessonCompleteEntrance {
  static const guide = Duration(milliseconds: 220);
  static const badge = Duration(milliseconds: 320);
  static const check = Duration(milliseconds: 480);
  static const title = Duration(milliseconds: 600);
  static const body = Duration(milliseconds: 720);
  static const xp = Duration(milliseconds: 800);
  static const chainNode = Duration(milliseconds: 900);
  static const chainLine = Duration(milliseconds: 1100);

  static const ringAfterData = Duration(milliseconds: 200);

  /// Reaching the goal is worth bringing the card into view for, once the card
  /// has opened its place.
  static const scrollAfterData = Duration(milliseconds: 300);
  static const goalAfterData = Duration(milliseconds: 700);
  static const flameAfterData = Duration(milliseconds: 720);
  static const rollAfterData = Duration(milliseconds: 800);
  static const metAfterData = Duration(milliseconds: 960);
}

/// Home's opening, once a day (design "Home Archipelago", M1): the map fades
/// in, each island rises in turn from the top, then the trail, the ring and
/// its guide, the bubble and the review box.
abstract final class HomeEntrance {
  static const map = Duration.zero;
  static const trail = Duration(milliseconds: 300);
  static const ring = Duration(milliseconds: 300);
  static const guide = Duration(milliseconds: 560);
  static const bubble = Duration(milliseconds: 880);
  static const box = Duration(milliseconds: 980);

  /// When island [index] (from the top) starts to rise.
  static Duration isle(int index) =>
      AppMotion.homeIsleDelay + AppMotion.homeIsleStagger * index;

  /// When everything has arrived, with [islands] on the map.
  static Duration settled(int islands) {
    final box = HomeEntrance.box + AppMotion.homeBoxIn;
    final isles = isle(islands < 1 ? 0 : islands - 1) + AppMotion.homeIsleRise;
    return box > isles ? box : isles;
  }
}
