import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'nfce_receipt_models.dart';
import 'product_catalog.dart';
import 'product_measure_unit.dart';

/// Dados editáveis de um produto manual (`manual_products`).
class ManualProductRecord {
  const ManualProductRecord({
    required this.id,
    required this.name,
    this.barcode,
    this.storeCode,
    this.brand,
    this.measureLabel,
    this.measureQty,
    this.measureUnitCode,
    this.photoRelativePath,
  });

  final String id;
  final String name;
  final String? barcode;
  final String? storeCode;
  final String? brand;

  /// Legado (antes de `measure_qty` / `measure_unit_code`).
  final String? measureLabel;
  final String? measureQty;
  final String? measureUnitCode;
  final String? photoRelativePath;
}

/// Dados extras do usuário por linha da NFC-e (foto, EAN e marca quando a nota veio vazia).
class ReceiptItemOverride {
  const ReceiptItemOverride({
    this.photoRelativePath,
    this.userBarcode,
    this.userBrand,
  });

  factory ReceiptItemOverride.fromRow(Map<String, Object?> r) {
    return ReceiptItemOverride(
      photoRelativePath: (r['photo_relative_path'] as String?)?.trim(),
      userBarcode: (r['user_barcode'] as String?)?.trim(),
      userBrand: (r['user_brand'] as String?)?.trim(),
    );
  }

  final String? photoRelativePath;
  final String? userBarcode;
  final String? userBrand;
}

/// Persistência de consultas NFC-e (payload JSON).
class NfceReceiptRepository {
  NfceReceiptRepository(this._db);

  final Database _db;

  /// Mais recentes primeiro.
  Future<List<NfceReceiptSummary>> listReceipts() async {
    final rows = await _db.query(
      'nfce_receipts',
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(NfceReceiptSummary.fromDbRow).toList();
  }

  Future<NfceReceiptDetail?> getReceiptById(String id) async {
    final rows = await _db.query(
      'nfce_receipts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final base = NfceReceiptDetail.fromDbRow(rows.first);
    if (base == null) return null;
    final ov = await _receiptOverridesByIndex(id);
    final merged = <Map<String, dynamic>>[
      for (var i = 0; i < base.items.length; i++)
        mergeReceiptItemForDisplay(base.items[i], i, ov[i]),
    ];
    return NfceReceiptDetail(
      id: base.id,
      sourceUrl: base.sourceUrl,
      emissionRaw: base.emissionRaw,
      createdAtMs: base.createdAtMs,
      items: merged,
      purchaseTotalRaw: base.purchaseTotalRaw,
      taxesTotalRaw: base.taxesTotalRaw,
    );
  }

  Future<Map<int, ReceiptItemOverride>> _receiptOverridesByIndex(
    String receiptId,
  ) async {
    final rows = await _db.query(
      'nfce_receipt_item_overrides',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
    final map = <int, ReceiptItemOverride>{};
    for (final r in rows) {
      map[r['item_index']! as int] = ReceiptItemOverride.fromRow(r);
    }
    return map;
  }

  /// Mescla payload bruto + override para UI (detalhe da compra).
  static Map<String, dynamic> mergeReceiptItemForDisplay(
    Map<String, dynamic> item,
    int itemIndex,
    ReceiptItemOverride? o,
  ) {
    final m = Map<String, dynamic>.from(item);
    m['_itemIndex'] = itemIndex;
    final nc = m['code']?.toString().trim();
    final noteCodeEmpty = nc == null || nc.isEmpty;
    final nb = m['brand']?.toString().trim();
    final noteBrandEmpty = nb == null || nb.isEmpty;
    m['_noteCodeEmpty'] = noteCodeEmpty;
    m['_noteBrandEmpty'] = noteBrandEmpty;
    if (noteCodeEmpty &&
        o?.userBarcode != null &&
        o!.userBarcode!.trim().isNotEmpty) {
      m['code'] = o.userBarcode!.trim();
    }
    if (noteBrandEmpty &&
        o?.userBrand != null &&
        o!.userBrand!.trim().isNotEmpty) {
      m['brand'] = o.userBrand!.trim();
    }
    final pr = o?.photoRelativePath?.trim();
    if (pr != null && pr.isNotEmpty) {
      m['appPhotoRelativePath'] = pr;
    }
    return m;
  }

  Future<ReceiptItemOverride?> getReceiptItemOverride(
    String receiptId,
    int itemIndex,
  ) async {
    final rows = await _db.query(
      'nfce_receipt_item_overrides',
      where: 'receipt_id = ? AND item_index = ?',
      whereArgs: [receiptId, itemIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReceiptItemOverride.fromRow(rows.single);
  }

  /// Item do payload JSON original (sem merge de overrides).
  Future<Map<String, dynamic>?> getReceiptRawItemAt(
    String receiptId,
    int itemIndex,
  ) async {
    final rows = await _db.query(
      'nfce_receipts',
      where: 'id = ?',
      whereArgs: [receiptId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final payload =
          jsonDecode(rows.first['payload_json']! as String) as Map<String, dynamic>;
      final rawItems = payload['items'];
      if (rawItems is! List) return null;
      if (itemIndex < 0 || itemIndex >= rawItems.length) return null;
      final raw = rawItems[itemIndex];
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertReceiptItemOverride({
    required String receiptId,
    required int itemIndex,
    String? photoRelativePath,
    String? userBarcode,
    String? userBrand,
  }) async {
    String? norm(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return null;
      return t;
    }

    await _db.insert(
      'nfce_receipt_item_overrides',
      {
        'receipt_id': receiptId,
        'item_index': itemIndex,
        'photo_relative_path': norm(photoRelativePath),
        'user_barcode': norm(userBarcode),
        'user_brand': norm(userBrand),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Todas as linhas de produto de todas as NFC-e salvas (dados do QR)
  /// e produtos cadastrados manualmente (código de barras).
  Future<List<PurchasedItemLine>> listAllPurchasedItemLines() async {
    final fromReceipts = await _listPurchasedLinesFromReceipts();
    final fromManual = await _listPurchasedLinesFromManualProducts();
    return [...fromReceipts, ...fromManual];
  }

  Future<List<PurchasedItemLine>> _listPurchasedLinesFromReceipts() async {
    final rows = await _db.query(
      'nfce_receipts',
      orderBy: 'created_at_ms DESC',
    );
    final out = <PurchasedItemLine>[];
    for (final row in rows) {
      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(row['payload_json']! as String);
        if (decoded is! Map) continue;
        payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        continue;
      }
      final rawItems = payload['items'];
      if (rawItems is! List) continue;
      final receiptId = row['id']! as String;
      final savedAt = row['created_at_ms']! as int;
      final emission = row['emission_raw']! as String;
      final ovMap = await _receiptOverridesByIndex(receiptId);
      for (var idx = 0; idx < rawItems.length; idx++) {
        final raw = rawItems[idx];
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final o = ovMap[idx];
        final noteCode = m['code']?.toString().trim();
        final effectiveCode = (noteCode != null && noteCode.isNotEmpty)
            ? noteCode
            : o?.userBarcode?.trim();
        final c =
            effectiveCode != null && effectiveCode.isNotEmpty ? effectiveCode : null;
        final noteBrand = m['brand']?.toString().trim();
        final effectiveBrand = (noteBrand != null && noteBrand.isNotEmpty)
            ? noteBrand
            : o?.userBrand?.trim();
        final b =
            effectiveBrand != null && effectiveBrand.isNotEmpty ? effectiveBrand : null;
        final photo = o?.photoRelativePath?.trim();
        final p = photo != null && photo.isNotEmpty ? photo : null;
        out.add(
          PurchasedItemLine(
            receiptId: receiptId,
            receiptSavedAtMs: savedAt,
            receiptEmissionRaw: emission,
            description: m['description']?.toString() ?? '',
            code: c,
            quantityText: m['quantity']?.toString() ?? '',
            unit: m['unit'] as String?,
            unitPrice: m['unitPrice'] as String?,
            lineTotal: m['lineTotal']?.toString() ?? '',
            brand: b,
            productPhotoRelativePath: p,
          ),
        );
      }
    }
    return out;
  }

  Future<List<PurchasedItemLine>> _listPurchasedLinesFromManualProducts() async {
    final rows = await _db.query(
      'manual_products',
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(_manualProductRowToLine).toList();
  }

  PurchasedItemLine _manualProductRowToLine(Map<String, Object?> row) {
    final id = row['id']! as String;
    final name = row['name']! as String;
    final barcode = (row['barcode'] as String?)?.trim();
    final storeCode = (row['store_code'] as String?)?.trim();
    final bc = barcode != null && barcode.isNotEmpty ? barcode : null;
    final sc = storeCode != null && storeCode.isNotEmpty ? storeCode : null;
    final primaryCode = bc ?? sc;
    final unitPriceRaw = (row['unit_price'] as String?)?.trim();
    final legacyMeasure = (row['measure_label'] as String?)?.trim();
    final mq = (row['measure_qty'] as String?)?.trim();
    final muc = (row['measure_unit_code'] as String?)?.trim();
    final brandRaw = (row['brand'] as String?)?.trim();
    final photoRel = (row['photo_relative_path'] as String?)?.trim();

    final unitEnum = ProductMeasureUnit.tryParseStorageCode(muc);
    String? measureOverride;
    if (mq != null && mq.isNotEmpty && unitEnum != null) {
      measureOverride = ProductMeasureUnit.formatMeasureLabel(mq, unitEnum);
    } else if (legacyMeasure != null && legacyMeasure.isNotEmpty) {
      measureOverride = legacyMeasure;
    }

    return PurchasedItemLine(
      receiptId: id,
      receiptSavedAtMs: row['created_at_ms']! as int,
      receiptEmissionRaw: '—',
      description: name,
      code: primaryCode,
      quantityText: '1',
      unit: null,
      unitPrice: unitPriceRaw != null && unitPriceRaw.isNotEmpty
          ? unitPriceRaw
          : null,
      lineTotal: unitPriceRaw ?? '',
      brand: brandRaw != null && brandRaw.isNotEmpty ? brandRaw : null,
      measureLabelOverride: measureOverride,
      storeCode: bc != null && sc != null ? sc : null,
      productPhotoRelativePath:
          photoRel != null && photoRel.isNotEmpty ? photoRel : null,
    );
  }

  /// Cadastro manual (ex.: produto lido por código de barras e ainda não visto em NFC-e).
  Future<String> insertManualProduct({
    required String name,
    String? barcode,
    String? storeCode,
    String? brand,
    String? unitPrice,
    required String measureQty,
    required String measureUnitCode,
  }) async {
    final id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    String? norm(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return null;
      return t;
    }

    await _db.insert('manual_products', {
      'id': id,
      'barcode': norm(barcode),
      'store_code': norm(storeCode),
      'name': name.trim(),
      'brand': norm(brand),
      'unit_price': norm(unitPrice),
      'measure_label': null,
      'measure_qty': measureQty.trim(),
      'measure_unit_code': measureUnitCode.trim(),
      'photo_relative_path': null,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> setManualProductPhotoRelativePath(
    String id,
    String? relativePath,
  ) async {
    await _db.update(
      'manual_products',
      {'photo_relative_path': relativePath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<ManualProductRecord?> getManualProduct(String id) async {
    final rows = await _db.query(
      'manual_products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ManualProductRecord(
      id: row['id']! as String,
      name: row['name']! as String,
      barcode: (row['barcode'] as String?)?.trim(),
      storeCode: (row['store_code'] as String?)?.trim(),
      brand: (row['brand'] as String?)?.trim(),
      measureLabel: (row['measure_label'] as String?)?.trim(),
      measureQty: (row['measure_qty'] as String?)?.trim(),
      measureUnitCode: (row['measure_unit_code'] as String?)?.trim(),
      photoRelativePath: (row['photo_relative_path'] as String?)?.trim(),
    );
  }

  /// Atualiza cadastro manual sem alterar preço (`unit_price`) nem data de criação.
  Future<void> updateManualProduct({
    required String id,
    required String name,
    String? barcode,
    String? storeCode,
    String? brand,
    required String measureQty,
    required String measureUnitCode,
  }) async {
    String? norm(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return null;
      return t;
    }

    await _db.update(
      'manual_products',
      {
        'barcode': norm(barcode),
        'store_code': norm(storeCode),
        'name': name.trim(),
        'brand': norm(brand),
        'measure_qty': measureQty.trim(),
        'measure_unit_code': measureUnitCode.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> savePayload({
    required String sourceUrl,
    required String emissionRaw,
    required Map<String, dynamic> payload,
  }) async {
    final id =
        'nfce_${DateTime.now().microsecondsSinceEpoch}_${sourceUrl.hashCode.abs()}';
    await _db.insert('nfce_receipts', {
      'id': id,
      'source_url': sourceUrl,
      'emission_raw': emissionRaw,
      'payload_json': jsonEncode(payload),
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
