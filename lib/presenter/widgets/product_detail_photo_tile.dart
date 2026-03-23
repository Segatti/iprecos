import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Área 4:3 do detalhe do produto — foto local ou placeholder.
class ProductDetailPhotoTile extends StatelessWidget {
  const ProductDetailPhotoTile({
    super.key,
    this.photoRelativePath,
  });

  final String? photoRelativePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rel = photoRelativePath?.trim();

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: rel == null || rel.isEmpty
            ? _placeholderFill(theme, missingFile: false)
            : FutureBuilder<String?>(
                future: _absolute(rel),
                builder: (context, snap) {
                  final abs = snap.data;
                  if (abs != null && File(abs).existsSync()) {
                    return Image.file(
                      File(abs),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    );
                  }
                  return _placeholderFill(theme, missingFile: true);
                },
              ),
      ),
    );
  }

  static Future<String?> _absolute(String relative) async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, relative);
  }

  Widget _placeholderFill(ThemeData theme, {required bool missingFile}) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            missingFile ? 'Foto não encontrada' : 'Foto não disponível',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              missingFile
                  ? 'O arquivo da imagem pode ter sido removido.'
                  : 'Produtos cadastrados por você podem ter foto (4:3). '
                      'Itens vindos só da NFC-e (QR SEFAZ) não trazem imagem.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
