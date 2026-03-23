import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/nfce_receipt_repository.dart';
import '../../data/product_photo_storage.dart';
import '../utils/product_image_picker_crop.dart';
import '../view_models/lists_view_model.dart';
import '../view_models/product_search_view_model.dart';

class ReceiptItemEditArgs {
  const ReceiptItemEditArgs({
    required this.receiptId,
    required this.itemIndex,
  });

  final String receiptId;
  final int itemIndex;
}

/// Edição de linha da NFC-e: foto sempre; código de barras e marca só se vazios na nota.
class ReceiptItemEditPage extends StatefulWidget {
  const ReceiptItemEditPage({
    super.key,
    required this.args,
    required this.repository,
    required this.productSearchViewModel,
    required this.listsViewModel,
  });

  final ReceiptItemEditArgs args;
  final NfceReceiptRepository repository;
  final ProductSearchViewModel productSearchViewModel;
  final ListsViewModel listsViewModel;

  @override
  State<ReceiptItemEditPage> createState() => _ReceiptItemEditPageState();
}

class _ReceiptItemEditPageState extends State<ReceiptItemEditPage> {
  final _barcode = TextEditingController();
  final _brand = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _title = 'Item da nota';

  bool _noteCodeEmpty = false;
  bool _noteBrandEmpty = false;

  ReceiptItemOverride? _existing;
  String? _existingPhotoAbs;
  String? _croppedPath;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await widget.repository.getReceiptRawItemAt(
      widget.args.receiptId,
      widget.args.itemIndex,
    );
    if (!mounted) return;
    if (raw == null) {
      setState(() {
        _loading = false;
        _error = 'Item não encontrado nesta nota.';
      });
      return;
    }

    final desc = raw['description']?.toString().trim() ?? '';
    final nc = raw['code']?.toString().trim();
    final nb = raw['brand']?.toString().trim();
    _noteCodeEmpty = nc == null || nc.isEmpty;
    _noteBrandEmpty = nb == null || nb.isEmpty;

    final ov = await widget.repository.getReceiptItemOverride(
      widget.args.receiptId,
      widget.args.itemIndex,
    );
    _existing = ov;
    if (_noteCodeEmpty) {
      _barcode.text = ov?.userBarcode ?? '';
    }
    if (_noteBrandEmpty) {
      _brand.text = ov?.userBrand ?? '';
    }

    final rel = ov?.photoRelativePath;
    _existingPhotoAbs = await ProductPhotoStorage.absolutePathForRelative(rel);

    setState(() {
      _title = desc.isEmpty ? 'Item da nota' : desc;
      _loading = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    _barcode.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final path = await pickAndCropProductPhoto(source);
    if (!mounted || path == null) return;
    setState(() {
      _croppedPath = path;
      _removePhoto = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      var photoRel = _existing?.photoRelativePath;
      if (_removePhoto) {
        await ProductPhotoStorage.deleteIfExistsRelative(photoRel);
        photoRel = null;
      }
      if (_croppedPath != null) {
        await ProductPhotoStorage.saveReceiptItemPhoto(
          widget.args.receiptId,
          widget.args.itemIndex,
          File(_croppedPath!),
        );
        photoRel = ProductPhotoStorage.relativePathForReceiptItem(
          widget.args.receiptId,
          widget.args.itemIndex,
        );
      }

      final ub = _noteCodeEmpty
          ? (_barcode.text.trim().isEmpty ? null : _barcode.text.trim())
          : null;
      final ubr = _noteBrandEmpty
          ? (_brand.text.trim().isEmpty ? null : _brand.text.trim())
          : null;

      await widget.repository.upsertReceiptItemOverride(
        receiptId: widget.args.receiptId,
        itemIndex: widget.args.itemIndex,
        photoRelativePath: photoRel,
        userBarcode: ub,
        userBrand: ubr,
      );

      await widget.productSearchViewModel.load();
      await widget.listsViewModel.load();
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar item')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar item')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Preços e quantidades vêm da nota fiscal e não podem ser alterados aqui.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
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
                onPressed: _saving ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Galeria'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Câmera'),
              ),
              if (_hasPhotoDisplayed)
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _croppedPath = null;
                            _removePhoto = true;
                          }),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Remover foto'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Código de barras (EAN)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          TextFormField(
            controller: _barcode,
            enabled: _noteCodeEmpty && !_saving,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _noteCodeEmpty
                  ? 'Opcional — preencha se a nota não trouxe código'
                  : 'Já consta na nota fiscal',
              isDense: true,
            ),
          ),
          if (!_noteCodeEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'A nota já informa um código para este item; o código de barras EAN não pode ser alterado aqui.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Marca', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          TextFormField(
            controller: _brand,
            enabled: _noteBrandEmpty && !_saving,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _noteBrandEmpty
                  ? 'Opcional'
                  : 'Já consta na nota fiscal',
              isDense: true,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          if (!_noteBrandEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'A nota já informa marca; não é possível alterar aqui.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasPhotoDisplayed {
    if (_removePhoto) return false;
    if (_croppedPath != null) return true;
    final p = _existingPhotoAbs;
    return p != null && File(p).existsSync();
  }

  Widget _buildPhotoPreview(ThemeData theme) {
    if (_removePhoto && _croppedPath == null) {
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
    if (_croppedPath != null) {
      return Image.file(
        File(_croppedPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    final path = _existingPhotoAbs;
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
            'Foto com recorte 4:3',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
