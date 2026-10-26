import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class ChildProfileState extends Equatable {
  const ChildProfileState({this.name = '', this.age});

  /// As typed; [displayName] is what the app shows and stores.
  final String name;
  final int? age;

  String get displayName => name.trim();

  bool get canContinue => displayName.isNotEmpty && age != null;

  ChildProfileState copyWith({String? name, int? age}) =>
      ChildProfileState(name: name ?? this.name, age: age ?? this.age);

  @override
  List<Object?> get props => [name, age];
}

/// "Tell us about your child": the child's first name and age. The name is
/// shown to the child only and is never required to be a real name.
class ChildProfileCubit extends Cubit<ChildProfileState> {
  ChildProfileCubit() : super(const ChildProfileState());

  void setName(String name) => emit(state.copyWith(name: name));

  void setAge(int age) => emit(state.copyWith(age: age));
}
