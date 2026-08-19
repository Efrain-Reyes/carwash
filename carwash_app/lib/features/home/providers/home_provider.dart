import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../expenses/models/expense_model.dart';
import '../../expenses/services/expense_service.dart';
import '../../reports/models/accounting_report.dart';
import '../../reports/services/reports_service.dart';
import '../../washes/models/wash_item.dart';
import '../../washes/services/washes_service.dart';

class HomeProvider extends ChangeNotifier {
  AccountingReport? _report;
  CurrentCashSessionResponse? _cashState;
  List<WashItem> _recentWashes = [];
  List<Expense> _todayExpenses = [];
  bool _loading = false;
  bool _cashActionLoading = false;
  String? _error;
  String? _cashError;

  AccountingReport? get report => _report;
  CurrentCashSessionResponse? get cashState => _cashState;
  PendingCashSummary? get pendingSummary => _cashState?.pendingSummary;
  List<WashItem> get recentWashes => _recentWashes;
  List<Expense> get todayExpenses => _todayExpenses;
  bool get loading => _loading;
  bool get cashActionLoading => _cashActionLoading;
  String? get error => _error;
  String? get cashError => _cashError;

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

    var reportFailed = false;
    var cashFailed = false;
    var fatalError =
        'No se pudo conectar con el servidor.\nVerifica tu red e intenta de nuevo.';

    try {
      _cashState = await ReportsService.getCurrentCashSession();
      _cashError = null;
      debugPrint(
        '[HomeProvider] cash state: ${_cashState?.cashSession?.status}',
      );
    } on DioException catch (e) {
      debugPrint('[HomeProvider] cash DioException: ${e.response?.statusCode}');
      cashFailed = true;
      _cashError = _parseDioError(e);
    } catch (_) {
      debugPrint('[HomeProvider] unexpected error loading cash');
      cashFailed = true;
      _cashError = 'No se pudo cargar la caja del día.';
    }

    try {
      _report = await ReportsService.getAccounting(
        dateFrom: today,
        dateTo: today,
      );
      debugPrint(
        '[HomeProvider] report OK — ingresos: ${_report?.resumen.ingresosLavados}, lavados: ${_report?.lavados.cantidad}',
      );
    } on DioException catch (e) {
      debugPrint('[HomeProvider] DioException: ${e.response?.statusCode}');
      reportFailed = true;
      if (e.response?.statusCode == 403) {
        fatalError = '';
      }
    } catch (_) {
      debugPrint('[HomeProvider] unexpected error loading report');
      reportFailed = true;
      fatalError = 'Error inesperado al cargar los datos.';
    }

    try {
      final openSessionId = _cashState?.cashSession?.isOpen == true
          ? _cashState!.cashSession!.id
          : null;
      _recentWashes = openSessionId != null
          ? await WashesService.getForCashSession(openSessionId)
          : await WashesService.getToday();
      debugPrint('[HomeProvider] recent washes: ${_recentWashes.length}');
    } catch (_) {
      debugPrint('[HomeProvider] error loading washes (silent)');
    }

    try {
      final expensesResult = await ExpenseService.getExpenses(
        dateFrom: today,
        dateTo: today,
        status: 'activo',
      );
      _todayExpenses = (expensesResult['expenses'] as List<Expense>?) ?? [];
      debugPrint('[HomeProvider] today expenses: ${_todayExpenses.length}');
    } catch (_) {
      debugPrint('[HomeProvider] error loading expenses (silent)');
    }

    if (!silent) {
      _error = reportFailed && cashFailed && fatalError.isNotEmpty
          ? fatalError
          : null;
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createFirstCashSession({
    required double openingAmount,
    String? notes,
  }) async {
    if (_cashActionLoading) return false;
    _cashActionLoading = true;
    _cashError = null;
    notifyListeners();

    try {
      await ReportsService.createCashSession(
        openingAmount: openingAmount,
        notes: notes,
      );
      await _fetch(silent: true);
      return true;
    } on DioException catch (e) {
      _cashError = _parseDioError(e);
      return false;
    } catch (_) {
      _cashError = 'No se pudo crear la primera caja.';
      return false;
    } finally {
      _cashActionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> closeCashSession({
    required int id,
    required double countedClosingAmount,
    String? notes,
  }) async {
    if (_cashActionLoading) return false;
    _cashActionLoading = true;
    _cashError = null;
    notifyListeners();

    try {
      await ReportsService.closeCashSession(
        id: id,
        countedClosingAmount: countedClosingAmount,
        notes: notes,
      );
      await _fetch(silent: true);
      return true;
    } on DioException catch (e) {
      _cashError = _parseDioError(e);
      return false;
    } catch (_) {
      _cashError = 'No se pudo cerrar la caja.';
      return false;
    } finally {
      _cashActionLoading = false;
      notifyListeners();
    }
  }

  String _parseDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'No se pudo conectar con el servidor.';
  }
}
