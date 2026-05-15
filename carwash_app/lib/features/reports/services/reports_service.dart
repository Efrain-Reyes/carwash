// ignore_for_file: avoid_print

import '../../../core/api/api_client.dart';
import '../data/report_timeline_model.dart';
import '../models/accounting_report.dart';

class ReportsService {
  ReportsService._();

  static Future<AccountingReport> getAccounting({
    required String dateFrom,
    required String dateTo,
  }) async {
    print('Loading accounting report...');
    print('date_from: $dateFrom date_to: $dateTo');
    final response = await ApiClient.instance.get(
      '/reports/accounting',
      queryParameters: {'date_from': dateFrom, 'date_to': dateTo},
    );
    final report = AccountingReport.fromJson(
      (response.data['data'] ?? response.data) as Map<String, dynamic>,
    );
    print('Report ingresos: ${report.resumen.ingresosLavados}');
    print('Report lavados cantidad: ${report.lavados.cantidad}');
    print('Report gastos total: ${report.resumen.totalGastos}');
    return report;
  }

  static Future<ReportTimelineModel> getAccountingTimeline({
    required String dateFrom,
    required String dateTo,
  }) async {
    print('Loading accounting timeline...');
    print('Timeline date_from: $dateFrom date_to: $dateTo');
    final response = await ApiClient.instance.get(
      '/reports/accounting/timeline',
      queryParameters: {'date_from': dateFrom, 'date_to': dateTo},
    );
    final timeline = ReportTimelineModel.fromJson(
      (response.data['data'] ?? response.data) as Map<String, dynamic>,
    );
    print('Timeline points: ${timeline.timeline.length}');
    return timeline;
  }

  static Future<CurrentCashSessionResponse> getCurrentCashSession() async {
    final response = await ApiClient.instance.get('/cash-sessions/current');
    return CurrentCashSessionResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  static Future<AccountingCash> createCashSession({
    required double openingAmount,
    String? notes,
  }) async {
    final response = await ApiClient.instance.post(
      '/cash-sessions',
      data: {
        'opening_amount': openingAmount,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return AccountingCash.fromJson(
      response.data['cash_session'] as Map<String, dynamic>,
    );
  }

  static Future<AccountingCash> closeCashSession({
    required int id,
    required double countedClosingAmount,
    String? notes,
  }) async {
    final response = await ApiClient.instance.patch(
      '/cash-sessions/$id/close',
      data: {
        'counted_closing_amount': countedClosingAmount,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return AccountingCash.fromJson(
      response.data['cash_session'] as Map<String, dynamic>,
    );
  }
}
