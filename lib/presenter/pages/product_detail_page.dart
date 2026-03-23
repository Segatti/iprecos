import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_route_paths.dart';
import '../../data/product_catalog.dart';
import '../view_models/product_search_view_model.dart';
import '../widgets/product_detail_photo_tile.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.viewModel,
    required this.row,
  });

  final ProductSearchViewModel viewModel;
  final ProductSearchRow row;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late ProductSearchRow _row;

  @override
  void initState() {
    super.initState();
    _row = widget.row;
  }

  @override
  void didUpdateWidget(covariant ProductDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.productKey != widget.row.productKey) {
      _row = widget.row;
    }
  }

  Future<void> _openEdit() async {
    final id = widget.viewModel.editableManualProductId(_row.productKey);
    if (id == null || !mounted) return;
    final newRow = await context.push<ProductSearchRow?>(
      AppRoutePaths.searchEditManual,
      extra: id,
    );
    if (!mounted) return;
    await widget.viewModel.load();
    if (!mounted) return;
    if (newRow != null) {
      setState(() => _row = newRow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.viewModel.detailForKey(_row.productKey);
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produto')),
        body: const Center(
          child: Text('Não foi possível carregar este produto.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final minPrice = ProductCatalog.minPriceInHistory(detail.history);
    final maxPrice = ProductCatalog.maxPriceInHistory(detail.history);
    final canEdit = widget.viewModel.editableManualProductId(_row.productKey) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _row.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Editar dados (sem alterar preços)',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEdit,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ProductDetailPhotoTile(
            photoRelativePath: detail.productPhotoRelativePath,
          ),
          const SizedBox(height: 24),
          Text('Nome', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(detail.displayName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Código de barras (EAN)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            detail.eanOrBarcodeHint ?? '—',
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            detail.eanOrBarcodeHint == null
                ? 'A nota não traz código de barras EAN; só o código interno da loja.'
                : 'Detectado como possível EAN numérico nas linhas salvas.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text('Código na nota', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            detail.storeProductCode ?? '—',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text('Marca', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            detail.brand ?? 'Não consta na NFC-e',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: detail.brand == null
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text('Preço unitário (última compra)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            detail.latestUnitPrice == '—'
                ? '—'
                : 'R\$ ${detail.latestUnitPrice}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text('Tamanho / medida', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(detail.measureLabel, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text(
            'Histórico de preços',
            style: theme.textTheme.titleMedium,
          ),
          if (detail.history.length > 1 &&
              minPrice != null &&
              maxPrice != null &&
              (maxPrice - minPrice).abs() > 0.0001) ...[
            const SizedBox(height: 8),
            Text(
              'Faixa nas compras salvas: R\$ ${_brl(minPrice)} – R\$ ${_brl(maxPrice)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...detail.history.map((h) {
            final when = ProductCatalog.formatSavedDate(h.receiptSavedAtMs);
            final emission = h.receiptEmissionRaw == '—' ? null : h.receiptEmissionRaw;
            final sub = StringBuffer('Salvo em $when');
            if (emission != null) {
              sub.write(' · Emissão $emission');
            }
            sub.write(' · Qtd ${h.quantityText}');
            if (h.unit != null && h.unit!.isNotEmpty) {
              sub.write(' (${h.unit})');
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  h.unitPrice == '—' ? '—' : 'R\$ ${h.unitPrice}',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(sub.toString()),
                trailing: h.lineTotal != null && h.lineTotal!.isNotEmpty
                    ? Text(
                        'Tot. R\$ ${h.lineTotal}',
                        style: theme.textTheme.bodySmall,
                      )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _brl(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    return '${parts[0]},${parts[1]}';
  }
}
