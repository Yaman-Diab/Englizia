import 'package:englizia/core/result/result.dart';
import 'package:equatable/equatable.dart';

abstract interface class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

final class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const [];
}
