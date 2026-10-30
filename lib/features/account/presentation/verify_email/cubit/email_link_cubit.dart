import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum EmailLinkView { verifying, verified, expired, failed }

final class EmailLinkState extends Equatable {
  const EmailLinkState({this.view = EmailLinkView.verifying, this.failure});

  final EmailLinkView view;
  final Failure? failure;

  @override
  List<Object?> get props => [view, failure];
}

/// The link in the confirmation email (requirements v3.0 §5.3). One out of
/// date, used already or without a token asks for a new one.
class EmailLinkCubit extends Cubit<EmailLinkState> {
  EmailLinkCubit(this._accounts, {required String token})
    : _token = token,
      super(const EmailLinkState());

  final AccountRepository _accounts;
  final String _token;

  Future<void> verify() async {
    if (_token.isEmpty) {
      emit(const EmailLinkState(view: EmailLinkView.expired));
      return;
    }
    emit(const EmailLinkState());
    final result = await _accounts.verifyEmail(_token);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const EmailLinkState(view: EmailLinkView.verified),
      Err(failure: LinkExpiredFailure()) => const EmailLinkState(
        view: EmailLinkView.expired,
      ),
      Err(:final failure) => EmailLinkState(
        view: EmailLinkView.failed,
        failure: failure,
      ),
    });
  }
}
