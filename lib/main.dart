import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_injector.dart';
import 'app_widget.dart';

/// Cliente OAuth tipo **Web** (Google Cloud Console → Credenciais).
///
/// Sem isso, no Android costuma falhar se você **não** usar `google-services.json`
/// com um cliente OAuth web incluído.
///
/// Ex.: `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com`
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GoogleSignIn.instance.initialize(
    serverClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
  );

  await configureDependencies();
  runApp(const AppWidget());
}
