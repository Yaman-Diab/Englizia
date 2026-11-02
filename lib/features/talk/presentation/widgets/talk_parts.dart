import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ✦, the mark of what the AI does (design "Talk").
class AiSpark extends StatelessWidget {
  const AiSpark({required this.size, this.color, super.key});

  final double size;
  final Color? color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M12 2.5c.6 4.6 2.9 6.9 7.5 7.5-4.6.6-6.9 2.9-7.5 7.5'
      '-.6-4.6-2.9-6.9-7.5-7.5 4.6-.6 6.9-2.9 7.5-7.5z" fill="#000000"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.string(
      _svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? context.colors.ai.text,
        BlendMode.srcIn,
      ),
    ),
  );
}

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
