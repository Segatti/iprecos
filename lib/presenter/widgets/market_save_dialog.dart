import 'package:flutter/material.dart';

import '../../data/nfce_receipt_repository.dart';
import '../view_models/qr_market_scanner_view_model.dart';

/// Resultado do diálogo: nome confirmado e, se o usuário tocou num mercado da lista, o id.
class MarketPickResult {
  const MarketPickResult({
    required this.marketName,
    this.preferredStoreId,
  });

  final String marketName;
  final String? preferredStoreId;
}

/// Solicita o nome do mercado e permite escolher um já cadastrado.
Future<MarketPickResult?> showMarketSaveDialog({
  required BuildContext context,
  required NfceScanPrepared prepared,
  required List<StoreRecord> stores,
}) async {
  final suggested = prepared.parseResult.emitterName?.trim();
  final controller = TextEditingController(text: suggested ?? '');
  String? selectedStoreId;

  bool nameMatchesSelectedStore(StoreRecord s) {
    return controller.text.trim().toLowerCase() == s.name.trim().toLowerCase();
  }

  try {
    return await showDialog<MarketPickResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          final q = controller.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? stores
              : stores
                  .where(
                    (e) => e.name.toLowerCase().contains(q),
                  )
                  .toList();

          void onFieldChanged(String _) {
            StoreRecord? match;
            if (selectedStoreId != null) {
              for (final s in stores) {
                if (s.id == selectedStoreId) {
                  match = s;
                  break;
                }
              }
            }
            if (match != null && !nameMatchesSelectedStore(match)) {
              selectedStoreId = null;
            }
            setLocal(() {});
          }

          return AlertDialog(
            title: const Text('Mercado da compra'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Informe ou selecione o mercado antes de salvar a nota (${prepared.parseResult.items.length} itens).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Nome do mercado',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: onFieldChanged,
                    ),
                    if (prepared.parseResult.emitterAddressLine != null &&
                        prepared.parseResult.emitterAddressLine!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Endereço na nota:\n${prepared.parseResult.emitterAddressLine}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Mercados cadastrados',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          q.isEmpty
                              ? 'Nenhum mercado ainda. Digite um nome para criar.'
                              : 'Nenhum mercado com esse texto. Será criado um novo ao salvar.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final s in filtered)
                            ListTile(
                              dense: true,
                              selected: selectedStoreId == s.id,
                              title: Text(s.name),
                              subtitle: s.addressLine != null &&
                                      s.addressLine!.isNotEmpty
                                  ? Text(
                                      s.addressLine!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () {
                                setLocal(() {
                                  selectedStoreId = s.id;
                                  controller.text = s.name;
                                });
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  String? pref = selectedStoreId;
                  if (pref != null) {
                    StoreRecord? s;
                    for (final e in stores) {
                      if (e.id == pref) {
                        s = e;
                        break;
                      }
                    }
                    if (s == null || !nameMatchesSelectedStore(s)) {
                      pref = null;
                    }
                  }
                  Navigator.of(ctx).pop(
                    MarketPickResult(marketName: name, preferredStoreId: pref),
                  );
                },
                child: const Text('Salvar nota'),
              ),
            ],
          );
        },
      );
    },
  );
  } finally {
    controller.dispose();
  }
}
