import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_route_paths.dart';
import '../../data/nfce_receipt_repository.dart';
import '../../data/product_photo_storage.dart';
import '../view_models/product_search_view_model.dart';
import 'product_register_page.dart';

/// Fluxo do menu "Cadastrar produto": câmera lê o código de barras, então:
///
/// * se o código já estiver registrado (em produtos manuais ou em NFC-e),
///   mostra um alerta dizendo que já está cadastrado e oferece "Abrir produto";
/// * caso contrário, abre a tela de cadastro com o EAN preenchido.
class ProductRegisterScanPage extends StatefulWidget {
  const ProductRegisterScanPage({
    super.key,
    required this.repository,
    required this.productSearchViewModel,
  });

  final NfceReceiptRepository repository;
  final ProductSearchViewModel productSearchViewModel;

  @override
  State<ProductRegisterScanPage> createState() =>
      _ProductRegisterScanPageState();
}

class _ProductRegisterScanPageState extends State<ProductRegisterScanPage> {
  late final MobileScannerController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.itf14,
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String? _barcodeValue(Barcode b) {
    final raw = b.rawValue?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final raw = _barcodeValue(capture.barcodes.first);
    if (raw == null) return;
    _busy = true;
    try {
      await _handleBarcode(raw);
    } finally {
      if (mounted) _busy = false;
    }
  }

  Future<void> _handleBarcode(String barcode) async {
    final existingManual =
        await widget.repository.findManualProductByBarcode(barcode);
    if (!mounted) return;

    if (existingManual != null) {
      await _showAlreadyRegistered(
        title: existingManual.name,
        photoRelativePath: existingManual.photoRelativePath,
        onOpen: () async {
          await widget.productSearchViewModel.load();
          if (!mounted) return;
          final row = widget.productSearchViewModel.rowMatchingBarcode(barcode);
          if (!mounted) return;
          if (row != null) {
            context.pushReplacement(
              '${AppRoutePaths.search}/p',
              extra: row,
            );
          } else {
            context.pop();
          }
        },
      );
      return;
    }

    final inReceipts = await widget.repository.receiptsContainBarcode(barcode);
    if (!mounted) return;

    if (inReceipts) {
      await widget.productSearchViewModel.load();
      if (!mounted) return;
      final row = widget.productSearchViewModel.rowMatchingBarcode(barcode);
      await _showAlreadyRegistered(
        title: row?.displayName ?? 'Produto da NFC-e',
        photoRelativePath: null,
        onOpen: () async {
          if (!mounted) return;
          if (row != null) {
            context.pushReplacement(
              '${AppRoutePaths.search}/p',
              extra: row,
            );
          } else {
            context.pop();
          }
        },
      );
      return;
    }

    if (!mounted) return;
    context.pushReplacement(
      AppRoutePaths.searchRegister,
      extra: ProductRegisterArgs(initialBarcode: barcode),
    );
  }

  Future<void> _showAlreadyRegistered({
    required String title,
    required String? photoRelativePath,
    required Future<void> Function() onOpen,
  }) async {
    final absPath =
        await ProductPhotoStorage.absolutePathForRelative(photoRelativePath);
    if (!mounted) return;

    final choice = await showDialog<_AlreadyRegisteredAction>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Produto já cadastrado'),
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
                ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esse código de barras já está vinculado a um produto.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_AlreadyRegisteredAction.continueScanning),
              child: const Text('Continuar escaneando'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_AlreadyRegisteredAction.openProduct),
              child: const Text('Abrir produto'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (choice == _AlreadyRegisteredAction.openProduct) {
      await onOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar produto')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = (constraints.maxWidth * 0.72).clamp(120.0, 340.0);
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2 - 16,
          );
          final scanRect = Rect.fromCenter(
            center: center,
            width: side,
            height: side,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: scanRect,
                onDetect: _onDetect,
              ),
              Positioned.fill(
                child: ScanWindowOverlay(
                  controller: _controller,
                  scanWindow: scanRect,
                  borderRadius: BorderRadius.circular(12),
                  borderColor: Colors.white,
                  borderWidth: 2,
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: Text(
                  'Escaneie o código de barras do produto para cadastrar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black87),
                        ],
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _AlreadyRegisteredAction { openProduct, continueScanning }
