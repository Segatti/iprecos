import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/nfce_receipt_repository.dart';
import '../../data/product_catalog.dart';
import '../../data/product_measure_unit.dart';
import '../../data/product_photo_storage.dart';
import '../utils/product_image_picker_crop.dart';
import '../view_models/lists_view_model.dart';
import '../view_models/product_search_view_model.dart';

/// Edição de produto manual: mesmos campos do cadastro, **sem** alterar preço.
class ProductEditManualPage extends StatefulWidget {
  const ProductEditManualPage({
    super.key,
    required this.manualProductId,
    required this.repository,
    required this.productSearchViewModel,
    required this.listsViewModel,
  });

  final String manualProductId;
  final NfceReceiptRepository repository;
  final ProductSearchViewModel productSearchViewModel;
  final ListsViewModel listsViewModel;

  @override
  State<ProductEditManualPage> createState() => _ProductEditManualPageState();
}

class _ProductEditManualPageState extends State<ProductEditManualPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _storeCode = TextEditingController();
  final _brand = TextEditingController();
  final _measureQty = TextEditingController();

  ProductMeasureUnit _measureUnit = ProductMeasureUnit.defaultUnit;
  String? _legacyMeasureLabel;
  String? _existingPhotoAbsolute;
  String? _dbPhotoRelative;
  String? _pendingCroppedPath;
  bool _removePhotoRequested = false;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.repository.getManualProduct(widget.manualProductId);
    if (!mounted) return;
    if (r == null) {
      setState(() {
        _loading = false;
        _error = 'Produto não encontrado.';
      });
      return;
    }
    _name.text = r.name;
    _barcode.text = r.barcode ?? '';
    _storeCode.text = r.storeCode ?? '';
    _brand.text = r.brand ?? '';
    final mq = r.measureQty;
    final muc = r.measureUnitCode;
    final unit = ProductMeasureUnit.tryParseStorageCode(muc);
    if (mq != null && mq.isNotEmpty && unit != null) {
      _measureQty.text = mq;
      _measureUnit = unit;
      _legacyMeasureLabel = null;
    } else {
      _measureQty.text = '1';
      _measureUnit = ProductMeasureUnit.defaultUnit;
      _legacyMeasureLabel = r.measureLabel;
    }
    _dbPhotoRelative = r.photoRelativePath;
    _existingPhotoAbsolute = await ProductPhotoStorage.absolutePathForRelative(
      r.photoRelativePath,
    );
    setState(() {
      _loading = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _storeCode.dispose();
    _brand.dispose();
    _measureQty.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final path = await pickAndCropProductPhoto(source);
    if (!mounted || path == null) return;
    setState(() {
      _pendingCroppedPath = path;
      _removePhotoRequested = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateManualProduct(
        id: widget.manualProductId,
        name: _name.text,
        barcode: _barcode.text,
        storeCode: _storeCode.text,
        brand: _brand.text,
        measureQty: _measureQty.text,
        measureUnitCode: _measureUnit.storageCode,
      );

      if (_removePhotoRequested && _pendingCroppedPath == null) {
        await ProductPhotoStorage.deleteIfExistsRelative(_dbPhotoRelative);
        await widget.repository.setManualProductPhotoRelativePath(
          widget.manualProductId,
          null,
        );
        _dbPhotoRelative = null;
        _existingPhotoAbsolute = null;
      }

      if (_pendingCroppedPath != null) {
        await ProductPhotoStorage.saveFromFile(
          widget.manualProductId,
          File(_pendingCroppedPath!),
        );
        final rel = ProductPhotoStorage.relativePathForProductId(
          widget.manualProductId,
        );
        await widget.repository.setManualProductPhotoRelativePath(
          widget.manualProductId,
          rel,
        );
        _dbPhotoRelative = rel;
        _existingPhotoAbsolute =
            await ProductPhotoStorage.absolutePathForRelative(rel);
        _pendingCroppedPath = null;
        _removePhotoRequested = false;
      }

      await widget.productSearchViewModel.load();
      await widget.listsViewModel.load();
      if (!mounted) return;
      final bc = _barcode.text.trim();
      final sc = _storeCode.text.trim();
      final key = ProductCatalog.canonicalKey(
        bc.isNotEmpty ? bc : (sc.isNotEmpty ? sc : null),
        _name.text.trim(),
      );
      final row = widget.productSearchViewModel.rowForProductKey(key);
      context.pop(row);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar produto')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar produto')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar produto'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'O preço cadastrado e o histórico vindo de notas não são alterados aqui.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPhotoPreview(theme),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Galeria'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: const Text('Câmera'),
                ),
                if (_hasPhotoDisplayed)
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _pendingCroppedPath = null;
                              _removePhotoRequested = true;
                            }),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Remover foto'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Nome', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Descrição do produto',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Informe o nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Código de barras (EAN)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Text('Código na nota', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            TextFormField(
              controller: _storeCode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Código interno da loja (opcional)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Text('Marca', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Opcional',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text('Tamanho / medida', style: theme.textTheme.labelLarge),
            if (_legacyMeasureLabel != null &&
                _legacyMeasureLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Medida antiga (texto livre): $_legacyMeasureLabel. Ajuste quantidade e unidade abaixo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            TextFormField(
              controller: _measureQty,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Somente números',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: ProductMeasureUnit.validateQtyField,
            ),
            const SizedBox(height: 8),
            DropdownMenuFormField<ProductMeasureUnit>(
              initialSelection: _measureUnit,
              enableSearch: false,
              label: const Text('Unidade'),
              onSelected: _saving
                  ? null
                  : (u) {
                      if (u != null) setState(() => _measureUnit = u);
                    },
              dropdownMenuEntries: [
                for (final u in ProductMeasureUnit.values)
                  DropdownMenuEntry<ProductMeasureUnit>(
                    value: u,
                    label: u.label,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasPhotoDisplayed {
    if (_removePhotoRequested) return false;
    if (_pendingCroppedPath != null) return true;
    final p = _existingPhotoAbsolute;
    return p != null && File(p).existsSync();
  }

  Widget _buildPhotoPreview(ThemeData theme) {
    if (_removePhotoRequested && _pendingCroppedPath == null) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            'Foto será removida ao salvar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (_pendingCroppedPath != null) {
      return Image.file(
        File(_pendingCroppedPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    final path = _existingPhotoAbsolute;
    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Proporção 4:3 após o recorte',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
