import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app_route_paths.dart';
import '../../data/nfce_receipt_models.dart';
import '../../data/nfce_receipt_repository.dart';
import '../view_models/product_search_view_model.dart';
import 'receipt_item_edit_page.dart';

class PurchaseDetailPage extends StatefulWidget {
  const PurchaseDetailPage({
    super.key,
    required this.receiptId,
    required this.repository,
    required this.productSearchViewModel,
  });

  final String receiptId;
  final NfceReceiptRepository repository;
  final ProductSearchViewModel productSearchViewModel;

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  Future<NfceReceiptDetail?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  Future<NfceReceiptDetail?> _loadDetail() =>
      widget.repository.getReceiptById(widget.receiptId);

  void _reloadDetail() {
    setState(() {
      _future = _loadDetail();
    });
  }

  String _formatSaved(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openReceiptItemEdit(BuildContext context, int itemIndex) async {
    await context.push<void>(
      AppRoutePaths.purchaseReceiptItemEdit,
      extra: ReceiptItemEditArgs(
        receiptId: widget.receiptId,
        itemIndex: itemIndex,
      ),
    );
    if (!context.mounted) return;
    _reloadDetail();
    await widget.productSearchViewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NfceReceiptDetail?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compra')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final detail = snapshot.data;
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compra')),
            body: const Center(child: Text('Compra não encontrada.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Itens da compra')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data de emissão',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail.emissionRaw == '—'
                          ? 'Não informada na página'
                          : detail.emissionRaw,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (detail.purchaseTotalRaw != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Valor total da compra',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'R\$ ${detail.purchaseTotalRaw}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                    if (detail.taxesTotalRaw != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Total aproximado de tributos',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'R\$ ${detail.taxesTotalRaw}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Salvo no app',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(_formatSaved(detail.createdAtMs)),
                    const SizedBox(height: 16),
                    Text(
                      'Link da consulta',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      detail.sourceUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: detail.sourceUrl),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copiado')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copiar link'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Produtos (${detail.items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...detail.items.asMap().entries.map((entry) {
                final itemIndex = entry.key;
                final i = entry.value;
                final name = i['description']?.toString() ?? '—';
                final qty = i['quantity']?.toString() ?? '';
                final unit = i['unit']?.toString();
                final unitPrice = i['unitPrice']?.toString();
                final total = i['lineTotal']?.toString() ?? '';
                final code = i['code']?.toString();
                final brand = i['brand']?.toString().trim();
                final sub = <String>[
                  if (qty.isNotEmpty) 'Qtd: $qty',
                  if (unit != null && unit.isNotEmpty) 'UN: $unit',
                  if (unitPrice != null && unitPrice.isNotEmpty)
                    'Unit: $unitPrice',
                  if (code != null && code.isNotEmpty) 'Cód: $code',
                  if (brand != null && brand.isNotEmpty) 'Marca: $brand',
                ].join(' · ');
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(name),
                    subtitle: sub.isEmpty ? null : Text(sub),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            total.isEmpty ? '—' : 'R\$ $total',
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Editar foto, código de barras ou marca',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: name.trim().isEmpty
                              ? null
                              : () => _openReceiptItemEdit(context, itemIndex),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
