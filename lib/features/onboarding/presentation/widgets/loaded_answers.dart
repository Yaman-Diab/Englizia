import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:flutter/widgets.dart';

/// The answers of an onboarding question whose choices come from the
/// server: a spinner while loading, the error with a retry, or [ready].
List<Widget> loadedAnswers({
  required LoadStatus status,
  required Failure? failure,
  required VoidCallback onRetry,
  required List<Widget> Function() ready,
}) => switch (status) {
  LoadStatus.loading => const [
    Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xxl),
      child: AppStateView.loading(),
    ),
  ],
  LoadStatus.failure => [
    AppStateView.error(message: failure!.localizedMessage, onRetry: onRetry),
  ],
  LoadStatus.ready => ready(),
};
