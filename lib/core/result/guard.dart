import 'package:englizia/core/error/failure_mapper.dart';
import 'package:englizia/core/result/result.dart';

/// The single error funnel for the data layer: every `*RepositoryImpl` wraps
/// its calls in [guard], and [FailureMapper] maps the error exactly once.
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } catch (error, stackTrace) {
    return Err(FailureMapper.fromError(error, stackTrace));
  }
}
