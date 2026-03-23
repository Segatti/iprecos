import 'package:flutter/material.dart';

import '../view_models/app_view_model.dart';

/// Tela inicial: saudação, ação de auth e atalhos principais.
///
/// A view recebe estado e callbacks do [AppViewModel] / roteador quando estiverem prontos.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.userName,
    required this.isAuthenticated,
    this.onAuthPressed,
    this.onMinhasListas,
    this.onMinhasCompras,
    this.onEscanearNota,
    this.onBuscarProduto,
  });

  /// Nome exibido após "Bem vindo, …". Quando vazio, usa um fallback amigável.
  final String userName;

  final bool isAuthenticated;

  /// Entrar ou sair (Google / sessão local quando existir).
  final VoidCallback? onAuthPressed;

  final VoidCallback? onMinhasListas;
  final VoidCallback? onMinhasCompras;
  final VoidCallback? onEscanearNota;
  final VoidCallback? onBuscarProduto;

  String get _displayName {
    final trimmed = userName.trim();
    if (trimmed.isEmpty) {
      return isAuthenticated ? 'usuário' : 'visitante';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Bem vindo, $_displayName',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onAuthPressed,
                    child: Text(isAuthenticated ? 'Sair' : 'Entrar'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Menu',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _HomeMenuTile(
                    icon: Icons.list_alt_rounded,
                    label: 'Minhas listas',
                    onTap: onMinhasListas,
                  ),
                  _HomeMenuTile(
                    icon: Icons.receipt_long_rounded,
                    label: 'Minhas compras',
                    onTap: onMinhasCompras,
                  ),
                  _HomeMenuTile(
                    icon: Icons.document_scanner_outlined,
                    label: 'Escanear nota',
                    onTap: onEscanearNota,
                  ),
                  _HomeMenuTile(
                    icon: Icons.search_rounded,
                    label: 'Buscar produto',
                    onTap: onBuscarProduto,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMenuTile extends StatelessWidget {
  const _HomeMenuTile({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
