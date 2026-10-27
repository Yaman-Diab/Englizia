import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// Finishes an email with a common domain in one tap (design "Create
/// Account v2"): shown above the keyboard while the email is typed, once
/// there is a name before the "@", and narrowed by what follows it.
class EmailSuggestions extends StatelessWidget {
  const EmailSuggestions({
    required this.email,
    required this.onPick,
    super.key,
  });

  final String email;

  /// The whole email to use.
  final ValueChanged<String> onPick;

  /// The designs' three; most learners use one of them.
  static const domains = ['gmail.com', 'hotmail.com', 'outlook.com'];

  static const _height = 36.0;

  /// The completed emails to offer for [email], best first.
  static List<String> suggestionsFor(String email) {
    final value = email.trim();
    final at = value.indexOf('@');
    final local = at < 0 ? value : value.substring(0, at);
    if (local.isEmpty || local.contains(' ')) return const [];
    final typed = at < 0 ? '' : value.substring(at + 1).toLowerCase();
    return [
      for (final domain in domains)
        if (domain.startsWith(typed) && domain != typed) '$local@$domain',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = suggestionsFor(email);
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (final (i, suggestion) in suggestions.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: _height,
                  child: OutlinedButton(
                    onPressed: () => onPick(suggestion),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(_height),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      foregroundColor: colors.textPrimary,
                      backgroundColor: colors.surface,
                      side: BorderSide(color: colors.border),
                      shape: const StadiumBorder(),
                      textStyle: context.texts.caption,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '@${suggestion.split('@').last}',
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
