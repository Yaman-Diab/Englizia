import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What a field's message says about its value.
enum FieldMessageTone {
  /// A rule to meet, not met yet ("8 characters at least").
  hint,
  error,
  success,
}

/// The line under a field. Never color alone: each tone has its own mark.
final class FieldMessage {
  const FieldMessage(this.text, this.tone);

  final String text;
  final FieldMessageTone tone;
}

/// The app's text field (account designs): the label always above, an icon
/// at the start, a halo while focused or wrong, and an optional [message]
/// under it with a mark per tone. An error shows in three ways at once —
/// border, mark and text — and [shakeTrigger] shakes the field when a send
/// is refused. [obscurable] adds the show/hide eye of a password.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.icon,
    required this.controller,
    this.focusNode,
    this.message,
    this.obscurable = false,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
    this.autofillHints,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.shakeTrigger,
    super.key,
  });

  final String label;
  final AppIcon icon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final FieldMessage? message;
  final bool obscurable;

  /// Shown dimmed and closed to edits, e.g. while the form is being sent.
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  /// For Latin values in an Arabic screen (email, password): typed left to
  /// right, still aligned under the label.
  final TextDirection? textDirection;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Object? shakeTrigger;

  static const _height = 56.0;
  static const _iconSize = 20.0;
  static const _eyeSize = 22.0;
  static const _markSize = 15.0;
  static const _halo = 4.0;
  static const _readOnlyOpacity = .55;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownFocus;
  bool _hidden = true;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final focused = _focus.hasFocus && !widget.readOnly;
    // An error stays, even while focused, until the value is edited.
    final error = widget.message?.tone == FieldMessageTone.error;
    final duration = AppMotion.resolve(context, AppMotion.quick);

    final (Color accent, Color halo) = switch ((error, focused)) {
      (true, _) => (colors.error.fill, colors.error.surface),
      (_, true) => (colors.primaryStrong, colors.primary.surface),
      _ => (context.scheme.outline, Colors.transparent),
    };
    final labelColor = error
        ? colors.error.text
        : focused
        ? colors.primary.text
        : colors.textPrimary;
    final ambient = Directionality.of(context);
    final direction = widget.textDirection ?? ambient;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );

    final field = ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final iconColor = focused || error
            ? accent
            : widget.controller.text.isEmpty
            ? context.scheme.outline
            : colors.textSecondary;
        return TextField(
          controller: widget.controller,
          focusNode: _focus,
          readOnly: widget.readOnly,
          obscureText: widget.obscurable && _hidden,
          enableSuggestions: !widget.obscurable,
          autocorrect: false,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          textDirection: direction,
          textAlign: direction == ambient ? TextAlign.start : TextAlign.end,
          autofillHints: widget.readOnly ? null : widget.autofillHints,
          maxLength: widget.maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: texts.body.copyWith(color: colors.textPrimary),
          cursorColor: colors.primaryStrong,
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            constraints: const BoxConstraints.tightFor(
              height: AppTextField._height,
            ),
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            // Centered: the decorator stretches its prefix to the field.
            prefixIcon: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AppIconView(
                widget.icon,
                size: AppTextField._iconSize,
                color: iconColor,
              ),
            ),
            suffixIcon: widget.obscurable
                ? IconButton(
                    onPressed: widget.readOnly
                        ? null
                        : () => setState(() => _hidden = !_hidden),
                    tooltip: _hidden
                        ? 'field_password_show'.tr()
                        : 'field_password_hide'.tr(),
                    icon: AppIconView(
                      _hidden ? AppIcon.eyeOff : AppIcon.eye,
                      size: AppTextField._eyeSize,
                      color: colors.textSecondary,
                    ),
                  )
                : null,
            enabledBorder: border(accent, error ? 2 : 1),
            focusedBorder: border(accent, 2),
            disabledBorder: border(accent, 1),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedDefaultTextStyle(
          duration: duration,
          style: texts.captionStrong.copyWith(color: labelColor),
          child: ExcludeSemantics(child: Text(widget.label)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Shake(
          trigger: widget.shakeTrigger,
          child: AnimatedOpacity(
            duration: duration,
            opacity: widget.readOnly ? AppTextField._readOnlyOpacity : 1,
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.fast),
              curve: AppMotion.out,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(color: halo, spreadRadius: AppTextField._halo),
                ],
              ),
              child: Semantics(label: widget.label, child: field),
            ),
          ),
        ),
        if (widget.message case final message?) ...[
          const SizedBox(height: AppSpacing.sm),
          _Message(message: message, duration: duration),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.duration});

  final FieldMessage message;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, color) = switch (message.tone) {
      FieldMessageTone.hint => (AppIcon.circle, colors.textSecondary),
      FieldMessageTone.error => (AppIcon.errorCircle, colors.error.text),
      FieldMessageTone.success => (AppIcon.checkCircle, colors.success.text),
    };
    return Semantics(
      liveRegion: message.tone == FieldMessageTone.error,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: duration,
            child: AppIconView(
              icon,
              key: ValueKey(icon),
              size: AppTextField._markSize,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm - AppSpacing.xxs),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: context.texts.caption.copyWith(color: color),
              child: Text(message.text),
            ),
          ),
        ],
      ),
    );
  }
}
