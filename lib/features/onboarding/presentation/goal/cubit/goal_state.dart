import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:equatable/equatable.dart';

final class GoalState extends Equatable {
  const GoalState({
    this.status = LoadStatus.loading,
    this.settings,
    this.selected,
    this.failure,
  });

  final LoadStatus status;
  final DailyGoalSettings? settings;

  /// The chosen goal in minutes; the default is preselected on load.
  final int? selected;
  final Failure? failure;

  bool get canContinue => status == LoadStatus.ready && selected != null;

  /// Position of the chosen option in the list, for the guide's mood.
  int? get selectedIndex {
    final options = settings?.options;
    if (options == null || selected == null) return null;
    final index = options.indexWhere((o) => o.minutes == selected);
    return index < 0 ? null : index;
  }

  /// Nullable fields take a function so they can be cleared: `failure: () => null`.
  GoalState copyWith({
    LoadStatus? status,
    DailyGoalSettings? Function()? settings,
    int? Function()? selected,
    Failure? Function()? failure,
  }) => GoalState(
    status: status ?? this.status,
    settings: settings != null ? settings() : this.settings,
    selected: selected != null ? selected() : this.selected,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, settings, selected, failure];
}
