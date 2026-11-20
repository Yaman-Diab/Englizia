import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';

/// The tracks the learner joined (`GET /api/v1/app/enrollments`), as the
/// server sends them: one read for whatever needs the active track, as the
/// server names an enrollment by its track.
final class EnrollmentsReader {
  const EnrollmentsReader(this._client);

  final ApiClient _client;

  Future<List<Map<String, Object?>>> all() async => [
    for (final item
        in asJsonMap(
              await _client.get(ApiEndpoints.enrollments),
            ).readList('items') ??
            const <Object?>[])
      asJsonMap(item),
  ];

  /// The one in use; with none marked, the first.
  static Map<String, Object?>? activeOf(
    List<Map<String, Object?>> enrollments,
  ) =>
      enrollments
          .where((enrollment) => enrollment.readBool('isActive') ?? false)
          .firstOrNull ??
      enrollments.firstOrNull;

  /// Null when no track is joined.
  Future<String?> activeTrackId() async =>
      activeOf(await all())?.readString('trackId');
}
