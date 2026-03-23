import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_route_paths.dart';
import '../../data/nfce_receipt_repository.dart';
import '../../data/product_catalog.dart';
import '../../data/product_measure_unit.dart';
import '../../data/product_photo_storage.dart';
import '../utils/product_image_picker_crop.dart';
import '../view_models/lists_view_model.dart';
import '../view_models/product_search_view_model.dart';

/// Argumentos opcionais ao abrir o cadastro (ex.: código lido no scanner).
class ProductRegisterArgs {
  const ProductRegisterArgs({this.initialBarcode});

  final String? initialBarcode;
}

/// Cadastro manual com os mesmos campos exibidos em [ProductDetailPage].
class ProductRegisterPage extends StatefulWidget {
  const ProductRegisterPage({
    super.key,
    required this.repository,
    required this.productSearchViewModel,
    required this.listsViewModel,
    this.initialBarcode,
  });

  final NfceReceiptRepository repository;
  final ProductSearchViewModel productSearchViewModel;
  final ListsViewModel listsViewModel;
  final String? initialBarcode;

  @override
  State<ProductRegisterPage> createState() => _ProductRegisterPageState();
}

class _ProductRegisterPageState extends State<ProductRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _storeCode;
  late final TextEditingController _brand;
  late final TextEditingController _unitPrice;
  late final TextEditingController _measureQty;
  ProductMeasureUnit _measureUnit = ProductMeasureUnit.defaultUnit;
  String? _croppedPhotoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _barcode = TextEditingController(text: widget.initialBarcode ?? '');
    _storeCode = TextEditingController();
    _brand = TextEditingController();
    _unitPrice = TextEditingController();
    _measureQty = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _storeCode.dispose();
    _brand.dispose();
    _unitPrice.dispose();
    _measureQty.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final path = await pickAndCropProductPhoto(source);
    if (!mounted || path == null) return;
    setState(() => _croppedPhotoPath = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = await widget.repository.insertManualProduct(
        name: _name.text,
        barcode: _barcode.text,
        storeCode: _storeCode.text,
        brand: _brand.text,
        unitPrice: _unitPrice.text,
        measureQty: _measureQty.text,
        measureUnitCode: _measureUnit.storageCode,
      );
      if (_croppedPhotoPath != null) {
        await ProductPhotoStorage.saveFromFile(id, File(_croppedPhotoPath!));
        await widget.repository.setManualProductPhotoRelativePath(
          id,
          ProductPhotoStorage.relativePathForProductId(id),
        );
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
      context.pop();
      if (row != null && mounted) {
        context.push('${AppRoutePaths.search}/p', extra: row);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar produto'),
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
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _croppedPhotoPath != null
                    ? Image.file(
                        File(_croppedPhotoPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : ColoredBox(
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
                      ),
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
                if (_croppedPhotoPath != null)
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _croppedPhotoPath = null),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Remover foto'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
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
                hintText: 'Ex.: 7891234567890',
                isDense: true,
              ),
              keyboardType: TextInputType.text,
            ),
            Text(
              'Se for numérico como nas notas, o app reconhece como possível EAN.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
            Text(
              'Preço unitário (última compra)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _unitPrice,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ex.: 12,50',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Text('Tamanho / medida', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            TextFormField(
              controller: _measureQty,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Somente números (ex.: 1 ou 500)',
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
            const SizedBox(height: 24),
            Text(
              'Histórico de preços',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Após salvar, este cadastro aparece aqui. Novas entradas surgem quando '
              'o produto constar em notas NFC-e escaneadas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
