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
