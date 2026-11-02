import 'dart:async';
import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/talk/data/datasources/talk_remote_data_source.dart';
import 'package:englizia/features/talk/data/models/talk_model.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/domain/repositories/talk_repository.dart';

final class TalkRepositoryImpl implements TalkRepository {
  TalkRepositoryImpl(this._remote, this._settings);

  final TalkRemoteDataSource _remote;
  final SettingsStorageService _settings;

  /// A turn sent again after a failure keeps its id, so the server counts it
  /// once.
  final _turnIds = <String, String>{};

  @override
  TalkHome? get keptHome {
    final kept = _settings.talk;
    if (kept == null) return null;
    try {
      return TalkHomeModel(asJsonMap(jsonDecode(kept))).toEntity();
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'The kept scenarios are unreadable');
      return null;
    }
  }

  @override
  Future<Result<TalkHome>> getHome() async {
    final result = await guard(() async => (await _remote.getHome()).json);
    switch (result) {
      case Ok(:final value):
        try {
          await _settings.setTalk(jsonEncode(value));
        } catch (error, stackTrace) {
          AppLogger.error(error, stackTrace, 'Keeping the scenarios failed');
        }
        return Ok(TalkHomeModel(value).toEntity());
      case Err(:final failure):
        final kept = keptHome;
        if (failure is NetworkFailure && kept != null) return Ok(kept);
        return Err(failure);
    }
  }

  @override
  Future<Result<Scenario>> getScenario(String id) =>
      guard(() async => (await _remote.getScenario(id)).toEntity());

  @override
  Future<Result<String>> start(String scenarioId) {
    final id = SettingsStorageService.randomId();
    return guard(() async {
      await _remote.start(
        talkStartToJson(conversationId: id, scenarioId: scenarioId),
      );
      return id;
    });
  }

  @override
  Future<Result<TalkReply>> say(
    String conversationId, {
    required int turn,
    required String text,
    required SaidVia via,
  }) {
    final turnId = _turnIds['$conversationId/$turn'] ??=
        SettingsStorageService.randomId();
    return guard(
      () async => (await _remote.say(
        conversationId,
        talkTurnToJson(turnId: turnId, text: text, via: via),
      )).toEntity(),
    );
  }

  @override
  Future<void> end(String conversationId) async {
    final result = await guard(() => _remote.end(conversationId));
    if (result case Err(:final failure)) {
      AppLogger.info('Ending a conversation failed: $failure');
    }
  }
}
