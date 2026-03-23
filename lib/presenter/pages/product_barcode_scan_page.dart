import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Leitor de código de barras para localizar ou cadastrar produto.
class ProductBarcodeScanPage extends StatefulWidget {
  const ProductBarcodeScanPage({super.key});

  @override
  State<ProductBarcodeScanPage> createState() => _ProductBarcodeScanPageState();
}

class _ProductBarcodeScanPageState extends State<ProductBarcodeScanPage> {
  late final MobileScannerController _controller;
  bool _done = false;

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

  void _onDetect(BarcodeCapture capture) {
    if (_done || capture.barcodes.isEmpty) return;
    final v = _barcodeValue(capture.barcodes.first);
    if (v == null) return;
    _done = true;
    context.pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código de barras')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Text(
              'Aponte para o código de barras do produto.',
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
      ),
    );
  }
}
