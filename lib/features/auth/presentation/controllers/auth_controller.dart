import 'package:get/get.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/session_provider.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/send_password_reset_usecase.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }

enum ResetStatus { idle, sending, sent, failed }

/// App-wide session: who is signed in, the login / reset flows. Registered
/// once in `InitialBindings` (permanent) because every feature needs it.
class AuthController extends GetxController implements SessionProvider {
  AuthController(this._login, this._logout, this._sendPasswordReset);

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final SendPasswordResetUseCase _sendPasswordReset;

  final Rx<AuthStatus> status = AuthStatus.unauthenticated.obs;
  final Rxn<AuthUser> user = Rxn<AuthUser>();
  final RxnString error = RxnString();
  final Rx<ResetStatus> resetStatus = ResetStatus.idle.obs;
  final RxnString resetError = RxnString();

  @override
  AuthUser? get currentUser => user.value;

  bool get isAuthenticated =>
      status.value == AuthStatus.authenticated && user.value != null;

  Future<void> login(String email, String password) async {
    status.value = AuthStatus.authenticating;
    error.value = null;
    user.value = null;
    final result = await _login(LoginParams(email: email, password: password));
    result.fold(
      (f) {
        status.value = AuthStatus.unauthenticated;
        error.value = f.message;
      },
      (u) {
        user.value = u;
        status.value = AuthStatus.authenticated;
      },
    );
  }

  void dismissError() => error.value = null;

  Future<void> logout() async {
    await _logout(const NoParams());
    user.value = null;
    error.value = null;
    status.value = AuthStatus.unauthenticated;
    resetStatus.value = ResetStatus.idle;
    resetError.value = null;
  }

  Future<void> sendPasswordReset(String email) async {
    resetStatus.value = ResetStatus.sending;
    resetError.value = null;
    final result = await _sendPasswordReset(email);
    result.fold((f) {
      resetStatus.value = ResetStatus.failed;
      resetError.value = f.message;
    }, (_) => resetStatus.value = ResetStatus.sent);
  }

  void clearReset() {
    resetStatus.value = ResetStatus.idle;
    resetError.value = null;
  }
}
