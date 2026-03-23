/// Unidade de medida do cadastro manual (armazenada em `measure_unit_code`).
enum ProductMeasureUnit {
  unidade,
  gramas,
  kilo,
  mililitros,
  litros;

  String get label => switch (this) {
        unidade => 'Unidade',
        gramas => 'Gramas',
        kilo => 'Kilo',
        mililitros => 'Mililitros',
        litros => 'Litros',
      };

  /// Valor persistido no SQLite.
  String get storageCode => switch (this) {
        unidade => 'unidade',
        gramas => 'g',
        kilo => 'kg',
        mililitros => 'ml',
        litros => 'l',
      };

  static ProductMeasureUnit? tryParseStorageCode(String? code) {
    final c = code?.trim();
    if (c == null || c.isEmpty) return null;
    for (final u in ProductMeasureUnit.values) {
      if (u.storageCode == c) return u;
    }
    return null;
  }

  static ProductMeasureUnit get defaultUnit => ProductMeasureUnit.unidade;

  /// Texto exibido no detalhe / lista (a partir de quantidade + unidade).
  static String formatMeasureLabel(String qtyRaw, ProductMeasureUnit unit) {
    final v = parsePositiveQty(qtyRaw);
    if (v == null) return qtyRaw.trim();
    final q = _formatQtyForDisplay(v);
    return switch (unit) {
      ProductMeasureUnit.unidade =>
        v == 1 ? '1 unidade' : '$q unidades',
      ProductMeasureUnit.gramas => '$q g',
      ProductMeasureUnit.kilo => '$q kg',
      ProductMeasureUnit.mililitros => '$q ml',
      ProductMeasureUnit.litros => '$q L',
    };
  }

  static double? parsePositiveQty(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    final n = double.tryParse(normalized);
    if (n == null || n <= 0) return null;
    return n;
  }

  static String? validateQtyField(String? input) {
    final s = input?.trim() ?? '';
    if (s.isEmpty) return 'Informe a quantidade';
    if (parsePositiveQty(s) == null) {
      return 'Use um número maior que zero (ex.: 1 ou 1,5)';
    }
    return null;
  }

  static String _formatQtyForDisplay(double v) {
    if (v == v.roundToDouble()) {
      return v.round().toString();
    }
    final s = v.toStringAsFixed(3);
    var t = s.replaceFirst(RegExp(r'\.?0+$'), '');
    if (t.isEmpty) return '0';
    final parts = t.split('.');
    if (parts.length == 1) return parts[0];
    return '${parts[0]},${parts[1]}';
  }
}
