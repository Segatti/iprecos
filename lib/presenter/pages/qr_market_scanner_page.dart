import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../view_models/qr_market_scanner_view_model.dart';

class QrMarketScannerPage extends StatefulWidget {
  const QrMarketScannerPage({super.key, required this.viewModel});

  final QrMarketScannerViewModel viewModel;

  @override
  State<QrMarketScannerPage> createState() => _QrMarketScannerPageState();
}

class _QrMarketScannerPageState extends State<QrMarketScannerPage> {
  late final MobileScannerController _controller;

  /// Enquanto o diálogo de erro estiver aberto, ignora novas leituras do QR.
  bool _blockingUntilErrorDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String? _barcodeValue(Barcode b) {
    final raw = b.rawValue?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final u = b.url?.url.trim();
    if (u != null && u.isNotEmpty) return u;
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_blockingUntilErrorDismissed) return;
    if (capture.barcodes.isEmpty) return;
    final raw = _barcodeValue(capture.barcodes.first);
    if (raw == null) return;

    final result = await widget.viewModel.processScannedValue(raw);
    if (!mounted || result.silent) return;

    if (result.success) {
      final parts = <String>['${result.itemCount} itens'];
      if (result.purchaseTotalRaw != null) {
        parts.add('total R\$ ${result.purchaseTotalRaw}');
      }
      if (result.taxesTotalRaw != null) {
        parts.add('tributos R\$ ${result.taxesTotalRaw}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nota salva: ${parts.join(' · ')}.')),
      );
      return;
    }

    if (!mounted) return;
    _blockingUntilErrorDismissed = true;

    final isWrongHost =
        result.message?.contains('sefaz.UF.gov.br') ?? false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(isWrongHost ? 'Código inválido' : 'Atenção'),
          content:
              Text(result.message ?? 'Não foi possível usar este QR code.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        _blockingUntilErrorDismissed = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear nota')),
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
                  'Centralize o QR code da nota no quadrado.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black87),
                    ],
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: widget.viewModel,
                builder: (_, _) {
                  if (!widget.viewModel.busy) return const SizedBox.shrink();
                  return const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
