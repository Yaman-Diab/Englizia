import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/mail/mail_app.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/wait_countdown.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum VerifyEmailMode {
  /// The address a link went to, with a way to get another.
  view,

  /// Correcting the address.
  edit,
}

/// Something that just happened, shown for a moment in the sheet.
enum VerifyEmailNotice { sent, noMailApp }

enum VerifyEmailAction { resend, change }

final class VerifyEmailState extends Equatable {
  const VerifyEmailState({
    required this.now,
    required this.resendAt,
    this.email,
    this.verified = false,
    this.reminderHidden = false,
    this.mode = VerifyEmailMode.view,
    this.draft = '',
    this.showsFieldError = false,
    this.taken = false,
    this.sending,
    this.notice,
    this.failure,
    this.sends = 1,
  });

  /// The account's email; null until known, and for those with none to confirm.
  final String? email;
  final bool verified;

  /// The learner hid the reminder for now. The badge in «أنا» stays.
  final bool reminderHidden;
  final VerifyEmailMode mode;
  final String draft;

  /// The address is incomplete: shown on sending, gone on editing.
  final bool showsFieldError;

  /// The address belongs to another account. Not an error of the learner's.
  final bool taken;

  /// What is on its way.
  final VerifyEmailAction? sending;
  final VerifyEmailNotice? notice;

  /// Why the last send failed, with a retry.
  final Failure? failure;

  /// The clock, ticking each second while waiting to resend.
  final DateTime now;

  /// When the link may be asked for again.
  final DateTime resendAt;

  /// Links sent so far, the first when the account was made; each one makes
  /// the next wait longer.
  final int sends;

  /// There is an email to talk about.
  bool get applies => email != null;

  bool get showsReminder => applies && !verified && !reminderHidden;

  Duration get waitLeft =>
      resendAt.isAfter(now) ? resendAt.difference(now) : Duration.zero;

  bool get waiting => waitLeft > Duration.zero;

  bool get canResend => !waiting && sending == null;

  VerifyEmailState copyWith({
    String? email,
    bool? verified,
    bool? reminderHidden,
    VerifyEmailMode? mode,
    String? draft,
    bool? showsFieldError,
    bool? taken,
    VerifyEmailAction? Function()? sending,
    VerifyEmailNotice? Function()? notice,
    Failure? Function()? failure,
    DateTime? now,
    DateTime? resendAt,
    int? sends,
  }) => VerifyEmailState(
    email: email ?? this.email,
    verified: verified ?? this.verified,
    reminderHidden: reminderHidden ?? this.reminderHidden,
    mode: mode ?? this.mode,
    draft: draft ?? this.draft,
    showsFieldError: showsFieldError ?? this.showsFieldError,
    taken: taken ?? this.taken,
    sending: sending != null ? sending() : this.sending,
    notice: notice != null ? notice() : this.notice,
    failure: failure != null ? failure() : this.failure,
    now: now ?? this.now,
    resendAt: resendAt ?? this.resendAt,
    sends: sends ?? this.sends,
  );

  @override
  List<Object?> get props => [
    email,
    verified,
    reminderHidden,
    mode,
    draft,
    showsFieldError,
    taken,
    sending,
    notice,
    failure,
    now,
    resendAt,
    sends,
  ];
}

/// Confirming the email (requirements v3.0 §5.3, design "Verify Email"): a quiet
/// reminder that never stops the learner. Only members have an email to confirm,
/// and those who came with Google or Apple arrive confirmed, so they see nothing.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  VerifyEmailCubit(
    this._accounts,
    this._mailApp,
    this._settings, {
    required bool Function() isMember,
    DateTime Function()? now,
  }) : _isMember = isMember,
       _countdown = WaitCountdown(now: now),
       super(_first((now ?? DateTime.now)()));

  static VerifyEmailState _first(DateTime now) =>
      VerifyEmailState(now: now, resendAt: now);

  /// How long hiding the reminder lasts. ASSUMPTION(api): S §5.3 says 3 days,
  /// and the panel's settings don't list it yet (docs/api/auth.md).
  static const reminderHiddenFor = Duration(days: 3);

  /// The wait before each resend, the last one repeating (S §5.3).
  static const waits = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  /// How long a notice stays in the sheet.
  static const noticeFor = Duration(seconds: 4);

  final AccountRepository _accounts;
  final MailApp _mailApp;
  final SettingsStorageService _settings;
  final bool Function() _isMember;
  final WaitCountdown _countdown;
  Timer? _noticeEnd;
  VerifyEmailAction? _lastAction;

  /// Reads the email's state, also on coming back to the app: it may have been
  /// confirmed elsewhere. A failure only leaves things as they are.
  Future<void> load() async {
    if (!_isMember()) return;
    final result = await _accounts.getEmail();
    if (isClosed) return;
    if (result case Ok(:final value) when value.email != null) {
      final hiddenUntil = _settings.emailReminderHiddenUntil;
      emit(
        state.copyWith(
          email: value.email,
          verified: value.verified,
          reminderHidden:
              hiddenUntil != null && hiddenUntil.isAfter(_countdown.now()),
        ),
      );
    }
  }

  /// «إخفاء التذكير».
  Future<void> hideReminder() async {
    emit(state.copyWith(reminderHidden: true));
    await _settings.setEmailReminderHiddenUntil(
      _countdown.now().add(reminderHiddenFor),
    );
  }

  /// The sheet is opening: it starts clean, while the wait goes on.
  void sheetOpened() => emit(
    state.copyWith(
      mode: VerifyEmailMode.view,
      showsFieldError: false,
      taken: false,
      notice: () => null,
      failure: () => null,
    ),
  );

  Future<void> openMailApp() async {
    final opened = await _mailApp.open();
    if (!opened && !isClosed) _notify(VerifyEmailNotice.noMailApp);
  }

  /// «أعد الإرسال», when the wait is over.
  Future<void> resend() async {
    if (state.canResend) await sendNow();
  }

  /// Sends a link with no wait: an expired link's «أرسل رابطًا جديدًا» asks for
  /// one the learner has no other way to get.
  Future<void> sendNow() async {
    if (state.sending != null) return;
    _lastAction = VerifyEmailAction.resend;
    emit(
      state.copyWith(
        sending: () => VerifyEmailAction.resend,
        failure: () => null,
        notice: () => null,
      ),
    );
    final result = await _accounts.resendEmailLink();
    if (isClosed) return;
    switch (result) {
      case Ok() || Err(failure: RateLimitFailure()):
        final next = waits[state.sends.clamp(0, waits.length - 1)];
        _startWait(next, sends: state.sends + 1);
        _notify(VerifyEmailNotice.sent);
      case Err(:final failure):
        emit(state.copyWith(sending: () => null, failure: () => failure));
    }
  }

  void startEditing() => emit(
    state.copyWith(
      mode: VerifyEmailMode.edit,
      draft: state.email,
      showsFieldError: false,
      taken: false,
      notice: () => null,
      failure: () => null,
    ),
  );

  void cancelEditing() => emit(
    state.copyWith(
      mode: VerifyEmailMode.view,
      showsFieldError: false,
      taken: false,
      failure: () => null,
    ),
  );

  void draftChanged(String value) {
    if (state.sending != null) return;
    emit(state.copyWith(draft: value, showsFieldError: false, taken: false));
  }

  /// «أرسل إلى البريد الجديد».
  Future<void> change() async {
    if (state.sending != null) return;
    final email = state.draft.trim();
    if (!AccountRules.isEmail(email)) {
      emit(state.copyWith(showsFieldError: true, taken: false));
      return;
    }
    if (email.toLowerCase() == state.email?.toLowerCase()) {
      cancelEditing();
      return;
    }
    _lastAction = VerifyEmailAction.change;
    emit(
      state.copyWith(
        sending: () => VerifyEmailAction.change,
        failure: () => null,
        notice: () => null,
      ),
    );
    final result = await _accounts.changeEmail(email);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(email: email, mode: VerifyEmailMode.view));
        _startWait(waits.first, sends: 1);
        _notify(VerifyEmailNotice.sent);
      case Err(failure: ConflictFailure()):
        emit(state.copyWith(sending: () => null, taken: true));
      case Err(failure: ValidationFailure()):
        emit(state.copyWith(sending: () => null, showsFieldError: true));
      case Err(:final failure):
        emit(state.copyWith(sending: () => null, failure: () => failure));
    }
  }

  /// Repeats what just failed.
  Future<void> retry() =>
      _lastAction == VerifyEmailAction.change ? change() : sendNow();

  void _startWait(Duration wait, {required int sends}) {
    final now = _countdown.now();
    final resendAt = now.add(wait);
    emit(
      state.copyWith(
        sending: () => null,
        sends: sends,
        now: now,
        resendAt: resendAt,
      ),
    );
    _countdown.start(
      resendAt,
      onTick: (now) {
        if (!isClosed) emit(state.copyWith(now: now));
      },
      onEnd: (now) {
        if (!isClosed) emit(state.copyWith(now: now));
      },
    );
  }

  void _notify(VerifyEmailNotice notice) {
    emit(state.copyWith(notice: () => notice));
    _noticeEnd?.cancel();
    _noticeEnd = Timer(noticeFor, () {
      if (!isClosed) emit(state.copyWith(notice: () => null));
    });
  }

  @override
  Future<void> close() async {
    _countdown.cancel();
    _noticeEnd?.cancel();
    return super.close();
  }
}
