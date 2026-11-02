import 'dart:async';
import 'dart:convert';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';

/// Changes kept on the phone until the server has them, in order, as a later one
/// may build on an earlier one. Each carries its own id, so sending it twice is
/// harmless. One the server refuses for good is dropped, so it can't hold the
/// rest back; any other failure leaves them for the next time.
final class SendQueue {
  SendQueue({
    required String? Function() read,
    required Future<void> Function(String json) write,
    required Future<void> Function(Map<String, Object?> entry) send,
  }) : _read = read,
       _write = write,
       _send = send;

  /// What the server answers to a change it will never take.
  static const refused = {400, 404, 409, 410, 422};

  final String? Function() _read;
  final Future<void> Function(String json) _write;
  final Future<void> Function(Map<String, Object?> entry) _send;
  Future<void>? _sending;

  /// What is waiting, oldest first.
  List<Map<String, Object?>> get entries {
    final saved = _read();
    if (saved == null) return [];
    try {
      return [
        for (final entry in jsonDecode(saved) as List<Object?>)
          asJsonMap(entry),
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'A send queue is unreadable');
      return [];
    }
  }

  Future<void> _keep(List<Map<String, Object?>> entries) async {
    try {
      await _write(jsonEncode(entries));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping a send queue failed');
    }
  }

  /// Keeps [entry], and tries to send it without waiting for the server.
  Future<void> add(Map<String, Object?> entry) async {
    await _keep([...entries, entry]);
    unawaited(flush());
  }

  /// Sends what is waiting. Never fails.
  Future<void> flush() async {
    await guard(
      () => _sending ??= _sendAll().whenComplete(() => _sending = null),
    );
  }

  Future<void> _sendAll() async {
    while (true) {
      final waiting = entries;
      if (waiting.isEmpty) return;
      try {
        await _send(waiting.first);
      } on ApiException catch (error, stackTrace) {
        if (!refused.contains(error.statusCode)) rethrow;
        AppLogger.error(error, stackTrace, 'A change refused, and dropped');
      }
      await _keep(entries.skip(1).toList());
    }
  }
}
