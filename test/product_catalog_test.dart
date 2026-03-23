import 'package:flutter_test/flutter_test.dart';
import 'package:iprecos/data/product_catalog.dart';

void main() {
  group('ProductCatalog', () {
    test('canonicalKey usa código quando existe', () {
      expect(
        ProductCatalog.canonicalKey('AR1', 'Nome'),
        'c:AR1',
      );
    });

    test('canonicalKey usa nome normalizado sem código', () {
      expect(
        ProductCatalog.canonicalKey(null, '  Leite   integral  '),
        'd:Leite integral',
      );
    });

    test('buildDetail agrega histórico pelo mesmo código', () {
      final lines = [
        PurchasedItemLine(
          receiptId: 'r2',
          receiptSavedAtMs: 2000,
          receiptEmissionRaw: 'b',
          description: 'Arroz',
          code: 'X1',
          quantityText: '1',
          unit: 'UND1',
          unitPrice: '11,50',
          lineTotal: '11,50',
        ),
        PurchasedItemLine(
          receiptId: 'r1',
          receiptSavedAtMs: 1000,
          receiptEmissionRaw: 'a',
          description: 'Arroz',
          code: 'X1',
          quantityText: '1',
          unit: 'UND1',
          unitPrice: '10,00',
          lineTotal: '10,00',
        ),
      ];
      final d = ProductCatalog.buildDetail('c:X1', lines);
      expect(d, isNotNull);
      expect(d!.latestUnitPrice, '11,50');
      expect(d.history.length, 2);
      expect(d.history.first.unitPrice, '11,50');
    });
  });
}
