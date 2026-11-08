import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:englizia/features/me/data/models/profile_model.dart';
import 'package:englizia/features/me/data/repositories/profile_repository_impl.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/pages/me_page.dart';
import 'package:englizia/features/me/presentation/me/widgets/me_sheets.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_track_repository.dart';
import '../../helpers/pump_app.dart';

class _Remote implements ProfileRemoteDataSource {
  var offline = false;
  final renamed = <String>[];

  @override
  Future<ProfileModel> getProfile() async {
    if (offline) throw const NetworkException('connectionError');
    return ProfileModel(mockProfileJson());
  }

  @override
  Future<void> rename(String name) async => renamed.add(name);

  @override
  Future<void> switchTrack(String enrollmentId) async {}

  @override
  Future<void> changeLevel(String enrollmentId, String levelId) async {}
}

void main() {
  setUpAll(initLocalizationForTests);

  final today = DateTime(2026, 11, 5, 10);

  group('the profile', () {
    test('every part of the bundled profile reads', () {
      final profile = mockProfile(now: today);

      expect(profile.name, isNotEmpty);
      expect(profile.active?.trackId, 'trk_general');
      expect(profile.active?.unit, 3);
      expect(profile.tracks.last.isSchool, isTrue);
      expect(profile.streak?.current, 7);
      expect(profile.points?.total, 1240);
      expect(profile.week?.days, hasLength(7));
      expect(profile.week?.days[profile.week!.today].date.day, today.day);
      expect(profile.week?.goalDays, 3);
      expect(profile.week?.days.last.future, isTrue);
      expect(profile.placement?.daysLeft(today), 12);
      expect(profile.wordBank?.due, 12);

      final kid = mockProfile(kids: true, now: today);
      expect(kid.active?.audience, TrackAudience.child);
      expect(kid.stars, 86);
    });

    test('a v0.1 profile: what the server leaves out isn\'t there', () {
      final profile = const ProfileModel({
        'name': 'Learner',
        'lessonsDone': 2,
        'learningDays': 3,
        'tracks': [
          {
            'enrollmentId': 'e',
            'trackId': 't',
            'title': 'T',
            'unit': 9,
            'units': 4,
          },
          {'title': 'broken'},
        ],
      }).toEntity();

      expect(profile.tracks, hasLength(1));
      expect(profile.active?.unit, 4, reason: 'within its units');
      expect(profile.streak, isNull);
      expect(profile.week, isNull);
      expect(profile.placement, isNull);
      expect(profile.wordsSaved, isNull);
      expect(() => const ProfileModel({}).toEntity(), throwsFormatException);
    });

    test('kept on the phone; «أنا» moves once a day', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsStorageService(
        await SharedPreferences.getInstance(),
      );
      final remote = _Remote();
      final repository = ProfileRepositoryImpl(remote, settings: settings);

      expect(repository.keptProfile, isNull);
      expect(await repository.getProfile(), isA<Ok<Object?>>());
      remote.offline = true;
      expect(await repository.getProfile(), isA<Err<Object?>>());
      expect(repository.keptProfile?.name, mockProfile().name);

      expect(repository.firstViewOn(today), isTrue);
      expect(
        repository.firstViewOn(today.add(const Duration(hours: 2))),
        isFalse,
      );
      expect(
        repository.firstViewOn(today.add(const Duration(days: 1))),
        isTrue,
      );
    });
  });

  group('the cubit', () {
    late FakeProfileRepository profiles;
    late FakeTrackRepository tracks;

    setUp(() {
      profiles = FakeProfileRepository(
        mockProfile(now: today),
        firstView: true,
      );
      tracks = FakeTrackRepository(
        tracks: [Ok(mockPublishedTracks())],
        levels: [Ok(mockEmarLevels())],
      );
    });

    MeCubit cubit({bool guest = false}) {
      final subject = MeCubit(
        profiles,
        tracks,
        isGuest: () => guest,
        now: () => today,
      );
      addTearDown(subject.close);
      return subject;
    }

    test('the kept profile first, then the server\'s', () async {
      profiles.kept = mockProfile(now: today).copyWith(name: 'Kept');
      final subject = cubit(guest: true);
      final states = <MeState>[];
      final listening = subject.stream.listen(states.add);
      await subject.start();
      await Future<void>.delayed(Duration.zero);
      await listening.cancel();

      expect(states.any((s) => s.profile?.name == 'Kept'), isTrue);
      expect(subject.state.profile?.name, profiles.profile.name);
      expect(subject.state.guest, isTrue);
      expect(subject.state.firstView, isTrue);
    });

    test('nothing kept and no server: the failure', () async {
      profiles.failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();
      expect(subject.state.load, LoadStatus.failure);
    });

    test('a new name shows at once; a failure puts it back', () async {
      final subject = cubit();
      await subject.start();

      expect(await subject.rename('  Sam  '), isNull);
      expect(subject.state.profile?.name, 'Sam');
      expect(profiles.names, ['Sam']);

      profiles.writeFailure = const NetworkFailure();
      expect(await subject.rename('Lee'), isA<NetworkFailure>());
      expect(subject.state.profile?.name, 'Sam');
    });

    test('another track: active at once, then told', () async {
      final subject = cubit();
      await subject.start();
      final emar = subject.state.profile!.tracks.last;

      await subject.switchTrack(emar);

      expect(profiles.switches, [emar.enrollmentId]);
      expect(subject.state.profile?.active?.enrollmentId, emar.enrollmentId);
      expect(subject.state.switched, emar.title);
      expect(subject.state.switches, 1);
    });

    test('another grade of the same track', () async {
      final subject = cubit();
      await subject.start();
      await subject.loadLevels();
      expect(subject.state.levels, hasLength(12));
      expect(subject.state.levels!.first.kidsMode, isTrue);

      await subject.changeLevel(subject.state.levels!.first);
      expect(profiles.levels.single.$2, 'lvl_emar_01');
      expect(subject.state.switches, 1);
    });

    test(
      'the parent\'s number: right opens, wrong doesn\'t, both change it',
      () {
        final subject = cubit();
        final first = subject.state.gate;
        expect(first % 10, isNot(0));
        expect(first, inInclusiveRange(21, 99));

        expect(subject.tryGate('1'), isFalse);
        expect(subject.state.parentOpen, isFalse);
        final second = subject.state.gate;
        expect(second, isNot(first));

        final arabic = String.fromCharCodes(
          '$second'.codeUnits.map((unit) => unit - 0x30 + 0x660),
        );
        expect(subject.tryGate(arabic), isTrue);
        expect(subject.state.parentOpen, isTrue);
        subject.lockParent();
        expect(subject.state.parentOpen, isFalse);
      },
    );

    test('digits of any script', () {
      expect(MeCubit.normalDigits('4${String.fromCharCode(0x667)} x'), '47');
      expect(MeCubit.normalDigits(String.fromCharCode(0x6F5)), '5');
    });
  });

  group('the page', () {
    late FakeProfileRepository profiles;
    late List<String> did;

    Future<MeCubit> pump(
      WidgetTester tester, {
      bool kids = false,
      bool guest = false,
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      did = [];
      profiles = FakeProfileRepository(mockProfile(kids: kids, now: today));
      final subject = MeCubit(
        profiles,
        FakeTrackRepository(
          tracks: [Ok(mockPublishedTracks())],
          levels: [Ok(mockEmarLevels())],
        ),
        isGuest: () => guest,
        now: () => today,
      );
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: Scaffold(
            body: MePage(
              actions: MeActions(
                onSettings: () => did.add('settings'),
                onPrivacy: () => did.add('privacy'),
                onWhatsApp: (number) => did.add('whatsapp $number'),
                onPractice: () => did.add('practice'),
                onCreateAccount: () => did.add('account'),
                onSignOut: () async => did.add('out'),
                onVerifyEmail: () async => did.add('verify'),
                onRetest: () => did.add('retest'),
                onJoin: (track) => did.add('join ${track.id}'),
              ),
            ),
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    testWidgets('who, the track, the numbers, the week and the menu', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(profiles.profile.name), findsOneWidget);
      expect(find.text('me_verified'.tr()), findsOneWidget);
      expect(find.text('الإنجليزية العامة'), findsOneWidget);
      expect(find.text('1,240'), findsOneWidget);
      expect(find.text('me_week_goal_days'.plural(3)), findsOneWidget);

      await tester.scrollUntilVisible(find.text('me_word_bank'.tr()), 300);
      await tester.tap(find.text('me_word_bank'.tr()));
      await tester.scrollUntilVisible(find.text('me_whatsapp'.tr()), 300);
      await tester.tap(find.text('me_whatsapp'.tr()));
      await tester.tap(find.text('me_privacy'.tr()));
      await tester.pump();
      expect(did, ['practice', 'whatsapp +000000000000', 'privacy']);
    });

    testWidgets('the name\'s sheet saves a new one', (tester) async {
      final subject = await pump(tester);

      await tester.tap(find.byTooltip('me_edit_name'.tr()));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Sam');
      await tester.pump();
      await tester.tap(find.text('common_save'.tr()));
      await settle(tester);

      expect(subject.state.profile?.name, 'Sam');
      expect(find.text('Sam'), findsOneWidget);
    });

    testWidgets('another track from «مساراتك», then «انتقلت إلى…»', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(find.text('me_switch_track'.tr()));
      await settle(tester);
      await tester.tap(find.text('منهاج إيمار'));
      await settle(tester);

      expect(subject.state.profile?.active?.isSchool, isTrue);
      expect(
        find.text('me_switched'.tr(args: ['منهاج إيمار'])),
        findsOneWidget,
      );
      expect(find.text('me_change_grade'.tr()), findsOneWidget);
    });

    testWidgets('«أضف مسارًا»: the joined ones checked, the rest to join', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('me_switch_track'.tr()));
      await settle(tester);
      await tester.tap(find.text('me_add_track'.tr()));
      await settle(tester);
      expect(find.bySemanticsLabel('me_joined'.tr()), findsNWidgets(2));
      await tester.tap(find.text('me_join'.tr()));
      await settle(tester);
      expect(did, ['join trk_kids']);
    });

    testWidgets('signing out asks first; a guest is offered an account', (
      tester,
    ) async {
      await pump(tester, guest: true);
      expect(find.text('me_guest_note'.tr()), findsOneWidget);

      await tester.scrollUntilVisible(find.text('me_sign_out'.tr()), 300);
      await tester.tap(find.text('me_sign_out'.tr()));
      await settle(tester);
      expect(find.text('me_sign_out_guest'.tr()), findsOneWidget);
      await tester.tap(find.text('me_create_first'.tr()));
      await settle(tester);
      expect(did, ['account']);
    });

    testWidgets('kids: the parent\'s part opens with the right number', (
      tester,
    ) async {
      final subject = await pump(tester, kids: true);
      expect(find.text('me_kid_stars'.plural(86)), findsOneWidget);
      expect(find.text('me_settings'.tr()), findsNothing);

      final wrong = subject.state.gate;
      await tester.tap(find.text('me_parent'.tr()));
      await settle(tester);
      expect(
        find.text('me_gate_question'.tr(args: [numberInWords(wrong)])),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await tester.tap(find.text('common_continue'.tr()));
      await settle(tester);
      expect(subject.state.parentOpen, isFalse);
      expect(subject.state.gate, isNot(wrong));

      await tester.tap(find.text('me_parent'.tr()));
      await settle(tester);
      await tester.enterText(find.byType(TextField), '${subject.state.gate}');
      await tester.pump();
      await tester.tap(find.text('common_continue'.tr()));
      await settle(tester);
      expect(subject.state.parentOpen, isTrue);
      expect(find.text('me_settings'.tr()), findsOneWidget);
      await tester.tap(find.text('me_lock'.tr()));
      await tester.pump();
      expect(find.text('me_settings'.tr()), findsNothing);
    });

    testLayouts('every part fits', (tester, layout) async {
      for (final kids in [false, true]) {
        await pump(
          tester,
          kids: kids,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        expect(tester.takeException(), isNull);
        if (!kids) {
          for (var i = 0; i < 4; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -600),
            );
            await settle(tester);
            expect(tester.takeException(), isNull);
          }
        }
      }
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
