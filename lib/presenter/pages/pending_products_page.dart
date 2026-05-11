import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_route_paths.dart';
import '../../data/product_catalog.dart';
import '../../data/product_photo_storage.dart';
import '../view_models/lists_view_model.dart';
import '../view_models/product_search_view_model.dart';

/// Produtos "pendentes": qualquer produto do catálogo (manual + NFC-e)
/// que está **sem foto** ou **sem código de barras** (EAN).
class PendingProductsPage extends StatefulWidget {
  const PendingProductsPage({
    super.key,
    required this.productSearchViewModel,
    required this.listsViewModel,
  });

  final ProductSearchViewModel productSearchViewModel;
  final ListsViewModel listsViewModel;

  @override
  State<PendingProductsPage> createState() => _PendingProductsPageState();
}

class _PendingProductsPageState extends State<PendingProductsPage> {
  bool _loading = true;
  List<_PendingProductItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await widget.productSearchViewModel.load();
    final rows = widget.productSearchViewModel.visibleRows;

    final items = <_PendingProductItem>[];
    for (final row in rows) {
      final detail =
          widget.productSearchViewModel.detailForKey(row.productKey);
      if (detail == null) continue;

      final missingBarcode = detail.eanOrBarcodeHint == null ||
          detail.eanOrBarcodeHint!.isEmpty;
      final relPath = detail.productPhotoRelativePath;
      final missingPhoto = relPath == null || relPath.isEmpty;
      if (!missingBarcode && !missingPhoto) continue;

      final abs = await ProductPhotoStorage.absolutePathForRelative(relPath);
      items.add(
        _PendingProductItem(
          row: row,
          missingBarcode: missingBarcode,
          missingPhoto: missingPhoto,
          photoAbsolutePath: abs,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openItem(_PendingProductItem item) async {
    final manualId = widget.productSearchViewModel
        .editableManualProductId(item.row.productKey);
    if (manualId != null) {
      await context.push(AppRoutePaths.searchEditManual, extra: manualId);
    } else {
      await context.push('${AppRoutePaths.search}/p', extra: item.row);
    }
    if (!mounted) return;
    await widget.listsViewModel.load();
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _items.isEmpty
              ? 'Produtos pendentes'
              : 'Produtos pendentes (${_items.length})',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.25,
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhum produto pendente.\nProdutos sem foto ou sem código de barras aparecem aqui.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final it = _items[index];
                      final missing = <String>[];
                      if (it.missingBarcode) missing.add('código de barras');
                      if (it.missingPhoto) missing.add('foto');
                      final subtitle = 'Faltando: ${missing.join(' e ')}';
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: _LeadingThumb(
                            absolutePath: it.photoAbsolutePath,
                          ),
                          title: Text(
                            it.row.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openItem(it),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _PendingProductItem {
  const _PendingProductItem({
    required this.row,
    required this.missingBarcode,
    required this.missingPhoto,
    required this.photoAbsolutePath,
  });

  final ProductSearchRow row;
  final bool missingBarcode;
  final bool missingPhoto;
  final String? photoAbsolutePath;
}

class _LeadingThumb extends StatelessWidget {
  const _LeadingThumb({required this.absolutePath});

  final String? absolutePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = absolutePath;
    final hasFile = path != null && File(path).existsSync();
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: hasFile
            ? Image.file(File(path), fit: BoxFit.cover)
            : ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
