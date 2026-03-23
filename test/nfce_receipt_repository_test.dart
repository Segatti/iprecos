import 'package:flutter_test/flutter_test.dart';
import 'package:iprecos/data/local/shopping_lists_database.dart';
import 'package:iprecos/data/nfce_receipt_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NfceReceiptRepository', () {
    Future<(Database, NfceReceiptRepository)> openRepo() async {
      final db = await ShoppingListsDatabase.openInMemory();
      return (db, NfceReceiptRepository(db));
    }

    test('listReceipts e getReceiptById após savePayload', () async {
      final (db, repo) = await openRepo();
      addTearDown(db.close);

      await repo.savePayload(
        sourceUrl: 'https://example.com/nfce/1',
        emissionRaw: '01/01/2025 10:00',
        payload: {
          'items': [
            {
              'description': 'Arroz',
              'quantity': '1',
              'lineTotal': '10,00',
            },
          ],
        },
      );

      final list = await repo.listReceipts();
      expect(list.length, 1);
      expect(list.single.sourceUrl, 'https://example.com/nfce/1');
      expect(list.single.emissionRaw, '01/01/2025 10:00');
      expect(list.single.itemCount, 1);

      final detail = await repo.getReceiptById(list.single.id);
      expect(detail, isNotNull);
      expect(detail!.items.length, 1);
      expect(detail.items.single['description'], 'Arroz');
    });

    test('listReceipts ordena do mais recente para o mais antigo', () async {
      final (db, repo) = await openRepo();
      addTearDown(db.close);

      await repo.savePayload(
        sourceUrl: 'https://a',
        emissionRaw: 'a',
        payload: {'items': []},
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.savePayload(
        sourceUrl: 'https://b',
        emissionRaw: 'b',
        payload: {'items': []},
      );

      final list = await repo.listReceipts();
      expect(list.length, 2);
      expect(list.first.sourceUrl, 'https://b');
      expect(list.last.sourceUrl, 'https://a');
    });

    test('listAllPurchasedItemLines agrega itens de várias notas', () async {
      final (db, repo) = await openRepo();
      addTearDown(db.close);

      await repo.savePayload(
        sourceUrl: 'https://a',
        emissionRaw: '01/01/2025',
        payload: {
          'items': [
            {
              'description': 'Arroz',
              'code': 'X1',
              'quantity': '1',
              'unit': 'UND1',
              'unitPrice': '10,00',
              'lineTotal': '10,00',
            },
          ],
        },
      );
      await repo.savePayload(
        sourceUrl: 'https://b',
        emissionRaw: '02/01/2025',
        payload: {
          'items': [
            {
              'description': 'Arroz',
              'code': 'X1',
              'quantity': '2',
              'unit': 'UND1',
              'unitPrice': '11,50',
              'lineTotal': '23,00',
            },
            {
              'description': 'Feijão',
              'quantity': '1',
              'unitPrice': '8,00',
              'lineTotal': '8,00',
            },
          ],
        },
      );

      final lines = await repo.listAllPurchasedItemLines();
      expect(lines.length, 3);
      final arroz = lines.where((l) => l.description == 'Arroz').toList();
      expect(arroz.length, 2);
    });

    test('insertManualProduct aparece em listAllPurchasedItemLines', () async {
      final (db, repo) = await openRepo();
      addTearDown(db.close);

      final id = await repo.insertManualProduct(
        name: 'Chocolate',
        barcode: '7891234567890',
        storeCode: 'G123',
        brand: 'Marca X',
        unitPrice: '5,99',
        measureQty: '500',
        measureUnitCode: 'g',
      );
      expect(id.startsWith('manual_'), isTrue);

      final lines = await repo.listAllPurchasedItemLines();
      expect(lines.length, 1);
      final l = lines.single;
      expect(l.description, 'Chocolate');
      expect(l.code, '7891234567890');
      expect(l.storeCode, 'G123');
      expect(l.brand, 'Marca X');
      expect(l.unitPrice, '5,99');
      expect(l.measureLabelOverride, '500 g');
    });

    test('updateManualProduct altera nome e mantém unit_price', () async {
      final (db, repo) = await openRepo();
      addTearDown(db.close);

      final id = await repo.insertManualProduct(
        name: 'Antigo',
        barcode: '789',
        unitPrice: '9,99',
        measureQty: '2',
        measureUnitCode: 'kg',
      );
      await repo.updateManualProduct(
        id: id,
        name: 'Novo',
        barcode: '789',
        storeCode: 'L1',
        brand: 'B',
        measureQty: '1,5',
        measureUnitCode: 'l',
      );

      final record = await repo.getManualProduct(id);
      expect(record, isNotNull);
      expect(record!.name, 'Novo');
      expect(record.storeCode, 'L1');
      expect(record.brand, 'B');
      expect(record.measureQty, '1,5');
      expect(record.measureUnitCode, 'l');

      final lines = await repo.listAllPurchasedItemLines();
      expect(lines.single.unitPrice, '9,99');
      expect(lines.single.description, 'Novo');
      expect(lines.single.measureLabelOverride, '1,5 L');
    });

    test('receipt item override mescla EAN e marca quando nota veio vazia', () async {
      final (db, repo) = await openRepo();
      addTearDown(db.close);

      await repo.savePayload(
        sourceUrl: 'https://nfce/item-override',
        emissionRaw: '10/10/2025',
        payload: {
          'items': [
            {
              'description': 'Leite',
              'quantity': '1',
              'lineTotal': '5,00',
            },
          ],
        },
      );
      final id = (await repo.listReceipts()).single.id;
      await repo.upsertReceiptItemOverride(
        receiptId: id,
        itemIndex: 0,
        userBarcode: '789123',
        userBrand: 'Marca Y',
      );

      final detail = await repo.getReceiptById(id);
      expect(detail!.items.single['code'], '789123');
      expect(detail.items.single['brand'], 'Marca Y');
      expect(detail.items.single['_noteCodeEmpty'], isTrue);
      expect(detail.items.single['_noteBrandEmpty'], isTrue);

      final lines = await repo.listAllPurchasedItemLines();
      expect(lines.single.code, '789123');
      expect(lines.single.brand, 'Marca Y');
    });

    test('receipt item override não substitui código já vindo da nota', () async {
      final (db, repo) = await openRepo();
      addTearDown(db.close);

      await repo.savePayload(
        sourceUrl: 'https://nfce/coded',
        emissionRaw: 'a',
        payload: {
          'items': [
            {
              'description': 'Produto',
              'code': 'INT-1',
              'quantity': '1',
              'lineTotal': '1,00',
            },
          ],
        },
      );
      final id = (await repo.listReceipts()).single.id;
      await repo.upsertReceiptItemOverride(
        receiptId: id,
        itemIndex: 0,
        userBarcode: '789999',
      );

      final detail = await repo.getReceiptById(id);
      expect(detail!.items.single['code'], 'INT-1');
      expect(detail.items.single['_noteCodeEmpty'], isFalse);

      final lines = await repo.listAllPurchasedItemLines();
      expect(lines.single.code, 'INT-1');
    });
  });
}
