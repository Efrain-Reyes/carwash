import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../reports/models/accounting_report.dart';
import '../../reports/services/reports_service.dart';
import '../../washes/models/wash_item.dart';
import '../../washes/services/washes_service.dart';

class HomeProvider extends ChangeNotifier {
  AccountingReport? _report;
  List<WashItem> _recentWashes = [];
  bool _loading = false;
  String? _error;

  AccountingReport?  get report       => _report;
  List<WashItem>     get recentWashes => _recentWashes;
  bool               get loading      => _loading;
  String?            get error        => _error;

  /// Carga inicial — muestra spinner mientras carga.
  Future<void> loadToday() async {
    if (_loading) return;
    await _fetch(silent: false);
  }

  /// Recarga después de registrar un lavado — actualiza sin spinner.
  Future<void> reload() async {
    _loading = false;
    debugPrint('[HomeProvider] reload() triggered');
    await _fetch(silent: true);
  }

  Future<void> _fetch({required bool silent}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    final today = Fmt.dateApi(DateTime.now());
    debugPrint('[HomeProvider] fetching for $today (silent: $silent)');

    try {
      _report = await ReportsService.getAccounting(
        dateFrom: today,
        dateTo: today,
      );
      debugPrint(
          '[HomeProvider] report OK — ingresos: ${_report?.resumen.ingresosLavados}, lavados: ${_report?.lavados.cantidad}');
    } on DioException catch (e) {
      debugPrint('[HomeProvider] DioException: ${e.response?.statusCode}');
      if (!silent) {
        _error = 'No se pudo conectar con el servidor.\nVerifica tu red e intenta de nuevo.';
      }
    } catch (_) {
      debugPrint('[HomeProvider] unexpected error loading report');
      if (!silent) _error = 'Error inesperado al cargar los datos.';
    }

    try {
      _recentWashes = await WashesService.getToday();
      debugPrint('[HomeProvider] recent washes: ${_recentWashes.length}');
    } catch (_) {
      debugPrint('[HomeProvider] error loading washes (silent)');
    }

    _loading = false;
    notifyListeners();
  }
}
