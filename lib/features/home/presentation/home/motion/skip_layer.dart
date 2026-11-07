import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/read_order.dart';
import 'package:flutter/widgets.dart';

/// While the unit's celebration runs (M6), a tap anywhere skips to its end
/// (design "Home Archipelago", motion §8). A screen reader finds it as one
/// button, «تخطَّ الاحتفال». Fill the stage with it, above everything.
class SkipLayer extends StatelessWidget {
  const SkipLayer({required this.active, required this.onSkip, super.key});

  final bool active;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return Semantics(
      container: true,
      sortKey: HomeReadOrder.skip,
      button: true,
      label: 'home_skip'.tr(),
      onTap: onSkip,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSkip,
        child: const SizedBox.expand(),
      ),
    );
  }
}
