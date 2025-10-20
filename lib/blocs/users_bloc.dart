import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';

// Events
abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

class LoadUsers extends UsersEvent {}

// States
abstract class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => [];
}

class UsersInitial extends UsersState {}

class UsersLoading extends UsersState {}

class UsersLoaded extends UsersState {
  final List<UserModel> users;

  const UsersLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UsersError extends UsersState {
  final String message;

  const UsersError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final AuthRepository _authRepository;

  UsersBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(UsersInitial()) {
    on<LoadUsers>(_onLoadUsers);
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<UsersState> emit) async {
    try {
      emit(UsersLoading());

      // Get all users from the repository
      final users = await _authRepository.getAllUsers();

      emit(UsersLoaded(users));
    } catch (e) {
      emit(UsersError('Error al cargar usuarios: ${e.toString()}'));
    }
  }
}
