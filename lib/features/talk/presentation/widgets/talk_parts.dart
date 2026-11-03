import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/ai_spark.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:flutter/material.dart';

/// The character's picture, or its initial while there is none: violet for
/// an AI conversation, blue for a written one.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    required this.character,
    required this.size,
    required this.kind,
    super.key,
  });

  final TalkCharacter character;
  final double size;
  final TalkKind kind;

  /// The initial's size against the circle's (design).
  static const _initialRatio = .4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = kind == TalkKind.ai ? colors.ai : colors.primary;
    final initial = Center(
      child: Text(
        character.name.characters.first.toUpperCase(),
        style: context.texts.title.copyWith(
          color: tone.text,
          fontSize: size * _initialRatio,
          height: 1,
        ),
      ),
    );
    final url = character.avatarUrl;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: tone.surface, shape: BoxShape.circle),
        child: url == null
            ? initial
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initial,
              ),
      ),
    );
  }
}

/// «✦ محادثة ذكية» or «محادثة مكتوبة».
class TalkKindBadge extends StatelessWidget {
  const TalkKindBadge({required this.kind, this.large = false, super.key});

  final TalkKind kind;

  /// The intro's, a little bigger than a scenario card's.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final ai = kind == TalkKind.ai;
    final height = large ? 26.0 : 22.0;
    final ink = ai ? colors.ai.text : colors.textSecondary;
    return Container(
      height: height,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: ai ? colors.ai.surface : colors.background,
        borderRadius: BorderRadius.circular(height / 2),
        border: ai ? null : Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ai) ...[
            AiSpark(size: large ? 12 : 10),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            ai ? 'talk_kind_ai'.tr() : 'talk_kind_written'.tr(),
            style: texts.captionStrong.copyWith(
              color: ink,
              fontSize: texts.caption.fontSize! * (large ? .92 : .85),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
