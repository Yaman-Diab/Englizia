import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/widgets/sheets/home_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Emar: where a page of the student's book is (bubble §12.3, frame 23ب).
/// The field starts empty every time; the hit, or null when dismissed.
Future<PageHit?> showPageSearchSheet(
  BuildContext context, {
  required HomeSnapshot home,
}) => showHomeSheet<PageHit>(
  context,
  builder: (_) => _PageSearchSheet(home: home),
);

class _PageSearchSheet extends StatefulWidget {
  const _PageSearchSheet({required this.home});

  final HomeSnapshot home;

  @override
  State<_PageSearchSheet> createState() => _PageSearchSheetState();
}

class _PageSearchSheetState extends State<_PageSearchSheet> {
  final _field = TextEditingController();
  int? _page;
  PageHit? _hit;

  /// Latin and Arabic-Indic digits only, as typed, three at most (the
  /// design's filter; [HomeRules.parsePage] reads them).
  static final _digits = [
    FilteringTextInputFormatter.allow(RegExp('[0-9\u0660-\u0669]')),
    LengthLimitingTextInputFormatter(3),
  ];

  static const _fieldHeight = 56.0;
  static const _fieldText = 22.0;

  void _changed(String text) {
    final page = HomeRules.parsePage(text);
    setState(() {
      _page = page;
      _hit = page == null ? null : HomeRules.findPage(widget.home, page);
    });
  }

  void _go() {
    if (_hit case final hit?) Navigator.of(context).pop(hit);
  }

  /// The book is the level's: «الصف السابع».
  String get _book {
    final level = widget.home.level;
    return level.name.isEmpty ? level.label : level.name;
  }

  String _result() {
    if (_field.text.isEmpty) {
      final range = HomeRules.bookRange(widget.home);
      if (range == null) return '';
      return 'home_page_empty'.tr(
        namedArgs: {'from': '${range.from}', 'to': '${range.to}'},
      );
    }
    final units = widget.home.units;
    return switch (_hit) {
      PageLessonHit(:final unitIndex, :final lessonIndex) =>
        'home_page_lesson'.tr(
          namedArgs: {
            'page': '$_page',
            'lesson': units[unitIndex].lessons[lessonIndex].title,
            'number': '${lessonIndex + 1}',
          },
        ),
      PageUnitHit(:final unitIndex) => 'home_page_unit'.tr(
        namedArgs: {
          'page': '$_page',
          'number': '${units[unitIndex].number}',
          'name': units[unitIndex].title,
        },
      ),
      null => 'home_page_none'.tr(args: [_book]),
    };
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final scheme = context.scheme;
    final number = HomeSheet.text(
      context,
      texts.bodyStrong,
      size: _fieldText,
      line: _fieldText,
      running: false,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: HomeSheet.gap,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'home_page_search'.tr(),
                style: HomeSheet.text(
                  context,
                  texts.title,
                  size: 20,
                  line: 28,
                  running: false,
                ),
              ),
            ),
            Text(
              'home_page_book'.tr(args: [_book]),
              style: HomeSheet.text(
                context,
                texts.caption,
                size: 13,
                line: 20,
              ).copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        // The label names the field, as the design's <label> does.
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                'home_page_label'.tr(),
                style: HomeSheet.text(
                  context,
                  texts.captionStrong,
                  size: 13,
                  line: 20,
                ),
              ),
              TextField(
                controller: _field,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                inputFormatters: _digits,
                onChanged: _changed,
                onSubmitted: (_) => _go(),
                style: number,
                decoration: InputDecoration(
                  hintText: 'home_page_hint'.tr(),
                  hintStyle: number.copyWith(color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                    vertical: (_fieldHeight - _fieldText) / 2,
                  ),
                  border: border(scheme.outline, 1.5),
                  enabledBorder: border(scheme.outline, 1.5),
                  focusedBorder: border(colors.primaryStrong, 2),
                ),
              ),
            ],
          ),
        ),
        Semantics(
          container: true,
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 22),
            child: Text(
              _result(),
              style: HomeSheet.text(context, texts.body, size: 14, line: 22)
                  .copyWith(
                    color: _field.text.isEmpty
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
            ),
          ),
        ),
        HomeSheetButton(
          label: 'home_page_go'.tr(),
          onPressed: _hit == null ? null : _go,
        ),
      ],
    );
  }
}
