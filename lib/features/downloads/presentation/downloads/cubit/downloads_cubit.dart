import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';
import 'package:englizia/features/downloads/domain/repositories/download_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class DownloadsState extends Equatable {
  const DownloadsState({
    this.available = false,
    this.lessons = const {},
    this.usage,
    this.wifiOnly = true,
    this.asking = false,
  });

  /// The panel offers downloads and the phone can keep them. Until it is
  /// known, and when it is false, nothing about downloads is shown.
  final bool available;

  /// Each lesson's download, by its id.
  final Map<String, LessonDownload> lessons;

  /// The room taken, for the downloads' page.
  final DownloadUsage? usage;
  final bool wifiOnly;

  /// The size of a download is being asked for, before it is offered.
  final bool asking;

  /// How many of [lessonIds] are on the phone.
  int keptOf(Iterable<String> lessonIds) => lessonIds
      .where((id) => lessons[id]?.status == DownloadStatus.done)
      .length;

  bool anyActive(Iterable<String> lessonIds) =>
      lessonIds.any((id) => lessons[id]?.active ?? false);

  DownloadsState copyWith({
    bool? available,
    Map<String, LessonDownload>? lessons,
    DownloadUsage? usage,
    bool? wifiOnly,
    bool? asking,
  }) => DownloadsState(
    available: available ?? this.available,
    lessons: lessons ?? this.lessons,
    usage: usage ?? this.usage,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    asking: asking ?? this.asking,
  );

  @override
  List<Object?> get props => [available, lessons, usage, wifiOnly, asking];
}

/// The lessons kept on the phone (ADR 22), for every screen that shows or
/// starts a download. One for the whole app: a download goes on while the
/// screens change.
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(this._downloads) : super(const DownloadsState());

  final DownloadRepository _downloads;
  StreamSubscription<List<LessonDownload>>? _changes;
  Future<void>? _starting;

  /// Safe to call from every screen that needs it: it runs once. While
  /// downloads aren't available (the settings didn't come, say) the next
  /// call asks again.
  Future<void> start() => _starting ??= _start().whenComplete(() {
    if (!state.available) _starting = null;
  });

  Future<void> _start() async {
    final available = await _downloads.available();
    if (isClosed || !available) return;
    _changes ??= _downloads.changes.listen(_show);
    emit(state.copyWith(available: true, wifiOnly: _downloads.wifiOnly));
    await tidy();
  }

  /// Carries on what was cut and drops what ran out: when the app opens, and
  /// when the connection is back.
  Future<void> tidy() async {
    if (!state.available) return;
    await _downloads.tidy();
    if (isClosed) return;
    _show(_downloads.downloads);
  }

  void _show(List<LessonDownload> downloads) {
    if (isClosed) return;
    emit(
      state.copyWith(
        lessons: {for (final lesson in downloads) lesson.lessonId: lesson},
      ),
    );
  }

  /// What [lessons] would take; the screen then offers it or says why not.
  Future<Result<DownloadEstimate>> estimate(
    List<DownloadRequest> lessons,
  ) async {
    emit(state.copyWith(asking: true));
    final result = await _downloads.estimate(lessons);
    if (!isClosed) emit(state.copyWith(asking: false));
    return result;
  }

  Future<void> download(List<DownloadRequest> lessons) =>
      _downloads.start(lessons);

  Future<void> remove(String lessonId) async {
    await _downloads.remove(lessonId);
    await loadUsage();
  }

  Future<void> removeAll() async {
    await _downloads.removeAll();
    await loadUsage();
  }

  Future<Failure?> loadUsage() async {
    final result = await _downloads.usage();
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(usage: value));
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  Future<void> setWifiOnly({required bool on}) async {
    emit(state.copyWith(wifiOnly: on));
    await _downloads.setWifiOnly(on: on);
  }

  /// The server counts these lessons completed: their downloads make room
  /// after the panel's while.
  Future<void> markDone(Set<String> lessonIds) async {
    if (!state.available || lessonIds.isEmpty) return;
    await _downloads.markDone(lessonIds);
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
