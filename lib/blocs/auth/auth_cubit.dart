import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> user;

  AuthAuthenticated({required this.user});
}

class AuthUnauthenticated extends AuthState {}

class AuthCubit extends Cubit<AuthState> {
  final ApiService apiService;

  AuthCubit({required this.apiService}) : super(AuthInitial());

  Future<void> checkAuthentication() async {
    emit(AuthLoading());
    final user = await apiService.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user: user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<String?> login(String username, String password) async {
    emit(AuthLoading());
    final errorMsg = await apiService.login(username, password);
    if (errorMsg == null) {
      final user = await apiService.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user: user));
        return null; // success
      } else {
        emit(AuthUnauthenticated());
        return 'Failed to fetch user profile after login.';
      }
    }
    emit(AuthUnauthenticated());
    return errorMsg;
  }

  Future<void> logout() async {
    emit(AuthLoading());
    await apiService.logout();
    emit(AuthUnauthenticated());
  }
}
