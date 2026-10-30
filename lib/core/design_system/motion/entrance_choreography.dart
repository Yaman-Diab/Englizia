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
  static const badgeGrow = AppMotion.fast;
  static const check = Duration(milliseconds: 500);
  static const checkDraw = Duration(milliseconds: 300);
  static const hop = Duration(milliseconds: 800);
  static const hopUp = Duration(milliseconds: 120);
  static const hopDown = Duration(milliseconds: 180);
  static const hopHeight = 10.0;
  static const action = Duration(milliseconds: 1100);
  static const actionFade = Duration(milliseconds: 200);

  /// When the last element has arrived.
  static Duration get settled => action + actionFade;
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
