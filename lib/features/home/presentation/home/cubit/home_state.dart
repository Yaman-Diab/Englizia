import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:equatable/equatable.dart';

/// The «تعلّم» tab: home as last known merged with the phone, the clock its
/// greeting and risk read, the connection, and what to celebrate.
final class HomeState extends Equatable {
  const HomeState({
    required this.now,
    this.load = LoadStatus.loading,
    this.failure,
    this.home,
    this.trackTitle,
    this.kidsHint = false,
    this.online = true,
    this.offlineFetch = false,
    this.refreshing = false,
    this.refreshFailed = false,
    this.openingDue = false,
    this.moment,
    this.momentId = 0,
    this.seenEvents = const {},
    this.switching = false,
    this.switches = 0,
    this.switchedTo,
    this.levelJustDone = false,
  });

  /// The clock the greeting and the risk read; it ticks each minute.
  final DateTime now;
  final LoadStatus load;

  /// Only while nothing is shown.
  final Failure? failure;

  /// From the server, or as kept, merged with the phone.
  final HomeSnapshot? home;

  /// The capsule's track before any data: the kept profile's active one.
  final String? trackTitle;

  /// The kids' shell and top bar before any data (the kept profile's track).
  final bool kidsHint;
  final bool online;

  /// The last automatic fetch found no connection.
  final bool offlineFetch;
  final bool refreshing;

  /// A refresh the learner asked for failed: «تعذّر التحديث».
  final bool refreshFailed;

  /// The day's opening (M1) hasn't played yet.
  final bool openingDue;

  /// What to celebrate after a return; [momentId] changes with each.
  final HomeMoment? moment;
  final int momentId;
  final Set<String> seenEvents;
  final bool switching;

  /// Grows with each track switch, for the strip «انتقلت إلى …».
  final int switches;
  final String? switchedTo;

  /// The level was completed in this session (M7 played): its card stands at
  /// the horizon, not in the notice area.
  final bool levelJustDone;

  bool get offline => !online || offlineFetch;

  bool get kids => home?.kids ?? kidsHint;

  bool get v01 => home?.v01 ?? false;

  /// «تدرّب»'s badge: what is due for review.
  int get badge {
    final home = this.home;
    if (home == null || kids || v01) return 0;
    return home.review?.total ?? 0;
  }

  HomeGreeting get greeting {
    final home = this.home;
    if (home != null) return HomeRules.greeting(home, now);
    return now.hour < HomeRules.morningUntilHour
        ? HomeGreeting.morning
        : HomeGreeting.evening;
  }

  HomeStatus get status {
    final home = this.home;
    if (home == null) return (kind: HomeStatusKind.next, minutesLeft: 0);
    return HomeRules.status(home);
  }

  bool get atRisk {
    final home = this.home;
    return home != null && HomeRules.atRisk(home, now);
  }

  /// [emailReminder] is the account's: a member's unconfirmed email, not
  /// hidden for now.
  HomeNotices notices({required bool emailReminder}) {
    final home = this.home;
    if (home == null) {
      return (
        top: refreshFailed
            ? HomeTopNotice.refreshFailed
            : offline
            ? HomeTopNotice.offline
            : HomeTopNotice.none,
        card: HomeCardNotice.none,
        event: null,
      );
    }
    return HomeRules.notices(
      home,
      seen: seenEvents,
      emailReminder: emailReminder,
      offline: offline,
      refreshFailed: refreshFailed,
    );
  }

  HomeState copyWith({
    DateTime? now,
    LoadStatus? load,
    Failure? Function()? failure,
    HomeSnapshot? home,
    String? Function()? trackTitle,
    bool? kidsHint,
    bool? online,
    bool? offlineFetch,
    bool? refreshing,
    bool? refreshFailed,
    bool? openingDue,
    HomeMoment? Function()? moment,
    int? momentId,
    Set<String>? seenEvents,
    bool? switching,
    int? switches,
    String? Function()? switchedTo,
    bool? levelJustDone,
  }) => HomeState(
    now: now ?? this.now,
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    home: home ?? this.home,
    trackTitle: trackTitle != null ? trackTitle() : this.trackTitle,
    kidsHint: kidsHint ?? this.kidsHint,
    online: online ?? this.online,
    offlineFetch: offlineFetch ?? this.offlineFetch,
    refreshing: refreshing ?? this.refreshing,
    refreshFailed: refreshFailed ?? this.refreshFailed,
    openingDue: openingDue ?? this.openingDue,
    moment: moment != null ? moment() : this.moment,
    momentId: momentId ?? this.momentId,
    seenEvents: seenEvents ?? this.seenEvents,
    switching: switching ?? this.switching,
    switches: switches ?? this.switches,
    switchedTo: switchedTo != null ? switchedTo() : this.switchedTo,
    levelJustDone: levelJustDone ?? this.levelJustDone,
  );

  @override
  List<Object?> get props => [
    now,
    load,
    failure,
    home,
    trackTitle,
    kidsHint,
    online,
    offlineFetch,
    refreshing,
    refreshFailed,
    openingDue,
    moment,
    momentId,
    seenEvents,
    switching,
    switches,
    switchedTo,
    levelJustDone,
  ];
}
