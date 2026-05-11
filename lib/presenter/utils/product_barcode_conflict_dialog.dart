import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/nfce_receipt_repository.dart';
import '../../data/product_photo_storage.dart';

/// Mostra um diálogo de confirmação quando o usuário tenta salvar um produto
/// com um `barcode` que já pertence a outro produto manual.
///
/// Retorna `true` se o usuário confirmou a sobrescrita do produto existente.
Future<bool> confirmOverwriteManualProductByBarcode({
  required BuildContext context,
  required ManualProductRecord existing,
}) async {
  final absPath =
      await ProductPhotoStorage.absolutePathForRelative(existing.photoRelativePath);
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Sobrescrever produto?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (absPath != null && File(absPath).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.file(File(absPath), fit: BoxFit.cover),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              existing.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Já existe um produto com esse código de barras. '
              'Deseja realmente sobrescrever o produto acima?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sobrescrever'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
