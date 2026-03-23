import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../view_models/app_view_model.dart';

/// Tela mínima de login com Google.
///
/// Configuração: veja comentários em [main] (`GOOGLE_WEB_CLIENT_ID`) e os arquivos
/// Android/iOS (SHA-1, `strings.xml`, URL scheme no Info.plist).
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.appViewModel});

  final AppViewModel appViewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Use sua conta Google para continuar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                onPressed: () => _onGooglePressed(context),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Continuar com Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onGooglePressed(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await appViewModel.signInWithGoogle();
      if (!context.mounted) return;
      if (appViewModel.session.authenticated) {
        context.pop();
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return;
      }
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível entrar: ${e.description ?? e.code.name}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Erro inesperado: $e')),
      );
    }
  }
}
