import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// When no store opened (App Update 02): a calm note, and the store's page in
/// a read-only field to copy into a browser. «نسخ» reads «نُسخ» for a moment,
/// and says so to a screen reader. Without a [link] only the note shows.
class StoreLinkField extends StatefulWidget {
  const StoreLinkField({required this.link, super.key});

  final Uri? link;

  @override
  State<StoreLinkField> createState() => _StoreLinkFieldState();
}

class _StoreLinkFieldState extends State<StoreLinkField> {
  static const _fieldHeight = 48.0;
  static const _buttonHeight = 40.0;
  static const _buttonMinWidth = 64.0;
  static const _iconSize = 20.0;

  var _copied = false;
  Timer? _reset;

  Future<void> _copy(Uri link) async {
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(AppMotion.copiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
    await SemanticsService.sendAnnouncement(
      View.of(context),
      'update_link_copied_semantics'.tr(),
      Directionality.of(context),
    );
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final link = widget.link;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.xxs,
                    ),
                    child: AppIconView(
                      AppIcon.infoCircle,
                      size: _iconSize,
                      color: colors.info.fill,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      link == null
                          ? 'update_store_failed_no_link'.tr()
                          : 'update_store_failed'.tr(),
                      style: texts.bodyStrong.copyWith(color: colors.info.text),
                    ),
                  ),
                ],
              ),
              if (link != null) ...[
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Container(
                  height: _fieldHeight,
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.md,
                    end: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          link.toString(),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texts.caption.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: _copied
                            ? 'update_link_copied_semantics'.tr()
                            : 'update_copy_semantics'.tr(),
                        excludeSemantics: true,
                        child: TextButton(
                          onPressed: () => _copy(link),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              _buttonMinWidth,
                              _buttonHeight,
                            ),
                            foregroundColor: colors.primary.text,
                            textStyle: texts.button,
                          ),
                          child: Text(
                            _copied ? 'update_copied'.tr() : 'update_copy'.tr(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
