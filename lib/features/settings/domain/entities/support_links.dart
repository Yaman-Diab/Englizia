import 'package:equatable/equatable.dart';

/// Support's WhatsApp number and the legal pages, set in the control panel
/// (`system/config`). Each is null until the panel has one.
final class SupportLinks extends Equatable {
  const SupportLinks({this.whatsapp, this.privacy, this.terms});

  static const none = SupportLinks();

  final String? whatsapp;
  final Uri? privacy;
  final Uri? terms;

  @override
  List<Object?> get props => [whatsapp, privacy, terms];
}
