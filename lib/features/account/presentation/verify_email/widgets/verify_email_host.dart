import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Route `extra` of home when an expired link asked for a new one.
final class SendEmailLinkRequest {
  const SendEmailLinkRequest();
}

/// Keeps the email's state up to date under [child]: coming back to the app
/// reads it again, as it may have been confirmed on another device. With
/// [sendLink], opens the sheet and sends a link as soon as the email is known.
class VerifyEmailHost extends StatefulWidget {
  const VerifyEmailHost({
    required this.child,
    this.sendLink = false,
    super.key,
  });

  final Widget child;
  final bool sendLink;

  @override
  State<VerifyEmailHost> createState() => _VerifyEmailHostState();
}

class _VerifyEmailHostState extends State<VerifyEmailHost> {
  late final AppLifecycleListener _lifecycle;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<VerifyEmailCubit>().load(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _sendOnce(BuildContext context, VerifyEmailState state) {
    if (_sent || state.verified) return;
    _sent = true;
    final cubit = context.read<VerifyEmailCubit>();
    showVerifyEmailSheet(context);
    cubit.sendNow();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<VerifyEmailCubit, VerifyEmailState>(
        listenWhen: (before, now) =>
            widget.sendLink && !before.applies && now.applies,
        listener: _sendOnce,
        child: widget.child,
      );
}
