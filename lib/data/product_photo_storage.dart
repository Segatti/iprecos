import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fotos de produtos manuais em `Documents/product_photos/{id}.jpg`.
/// Linhas de nota em `Documents/receipt_item_photos/…`.
abstract final class ProductPhotoStorage {
  static const subdir = 'product_photos';
  static const receiptItemSubdir = 'receipt_item_photos';

  static String relativePathForReceiptItem(String receiptId, int itemIndex) {
    final h = receiptId.hashCode.abs();
    return p.join(receiptItemSubdir, 'r${h}_i$itemIndex.jpg');
  }

  static Future<File> _fileForReceiptItem(String receiptId, int itemIndex) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, receiptItemSubdir));
    await dir.create(recursive: true);
    final name = 'r${receiptId.hashCode.abs()}_i$itemIndex.jpg';
    return File(p.join(dir.path, name));
  }

  static Future<void> saveReceiptItemPhoto(
    String receiptId,
    int itemIndex,
    File source,
  ) async {
    final dest = await _fileForReceiptItem(receiptId, itemIndex);
    await dest.writeAsBytes(await source.readAsBytes());
  }

  static Future<File> _fileForProductId(String productId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, subdir));
    await dir.create(recursive: true);
    return File(p.join(dir.path, '$productId.jpg'));
  }

  /// Caminho relativo ao diretório de documentos (para gravar no SQLite).
  static String relativePathForProductId(String productId) {
    return p.join(subdir, '$productId.jpg');
  }

  static Future<void> saveFromFile(String productId, File source) async {
    final dest = await _fileForProductId(productId);
    await dest.writeAsBytes(await source.readAsBytes());
  }

  static Future<String?> absolutePathForRelative(String? relative) async {
    if (relative == null || relative.isEmpty) return null;
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, relative);
  }

  static Future<void> deleteIfExistsRelative(String? relative) async {
    if (relative == null || relative.isEmpty) return;
    final abs = await absolutePathForRelative(relative);
    if (abs == null) return;
    final f = File(abs);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
