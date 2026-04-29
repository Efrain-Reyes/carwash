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
}
