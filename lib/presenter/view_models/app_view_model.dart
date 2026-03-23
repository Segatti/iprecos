import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Modelo de sessão exibido na UI (ex.: home).
@immutable
class AppSession {
  const AppSession({
    this.authenticated = false,
    this.userName = '',
  });

  final bool authenticated;
  final String userName;
}

/// ViewModel da aplicação (sessão + Google Sign-In).
class AppViewModel extends ChangeNotifier {
  AppSession _session = const AppSession();

  AppSession get session => _session;

  Future<void> signInWithGoogle() async {
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final name = account.displayName?.trim();
      final email = account.email.trim();
      _session = AppSession(
        authenticated: true,
        userName: (name != null && name.isNotEmpty)
            ? name
            : (email.isNotEmpty ? email : 'usuário'),
      );
      notifyListeners();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_session.authenticated) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    _session = const AppSession();
    notifyListeners();
  }
}
