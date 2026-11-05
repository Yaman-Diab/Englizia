import 'dart:convert';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/home/data/datasources/home_remote_data_source.dart';
import 'package:englizia/features/home/data/models/home_model.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/repositories/home_repository.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';

final class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._remote, {required SettingsStorageService settings})
    : _settings = settings;

  final HomeRemoteDataSource _remote;
  final SettingsStorageService _settings;

  @override
  HomeSnapshot? get keptHome {
    final saved = _settings.home;
    if (saved == null) return null;
    try {
      return HomeModel(asJsonMap(jsonDecode(saved))).toEntity();
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Kept home unreadable');
      return null;
    }
  }

  @override
  Future<Result<HomeSnapshot>> getHome() => guard(() async {
    final model = await _remote.getHome();
    final home = model.toEntity();
    try {
      await _settings.setHome(jsonEncode(model.json));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping home failed');
    }
    return home;
  });

  @override
  bool openingShownOn(String dayKey) => _settings.homeOpeningDay == dayKey;

  @override
  Future<void> setOpeningShown(String dayKey) async {
    try {
      await _settings.setHomeOpeningDay(dayKey);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping the opening day failed');
    }
  }

  @override
  Set<String> get seenEvents => _settings.homeSeenEvents.toSet();

  @override
  Future<void> markEventSeen(String id) async {
    final seen = [
      for (final saved in _settings.homeSeenEvents)
        if (saved != id) saved,
      id,
    ];
    final kept = seen.length > HomeRules.seenEventsKept
        ? seen.sublist(seen.length - HomeRules.seenEventsKept)
        : seen;
    try {
      await _settings.setHomeSeenEvents(kept);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping a seen notice failed');
    }
  }
}
