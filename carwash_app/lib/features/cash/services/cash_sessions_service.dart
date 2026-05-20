import '../../../core/api/api_client.dart';
import '../models/cash_session_model.dart';

class CashSessionsService {
  CashSessionsService._();

  static Future<List<CashSessionModel>> getCashSessions({
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;

    final response = await ApiClient.instance.get(
      '/cash-sessions',
      queryParameters: params.isEmpty ? null : params,
    );
    final data = (response.data['data'] as List?) ?? [];
    return data
        .map((item) => CashSessionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<CashSessionModel> getCashSession(int id) async {
    final response = await ApiClient.instance.get('/cash-sessions/$id');
    return CashSessionModel.fromJson(
      response.data['cash_session'] as Map<String, dynamic>,
    );
  }

  static Future<CashSessionAdjustmentResult> adjustClosing({
    required int id,
    required double countedClosingAmount,
    required String reason,
    String? notes,
  }) async {
    final response = await ApiClient.instance.patch(
      '/cash-sessions/$id/closing-adjustment',
      data: {
        'counted_closing_amount': countedClosingAmount,
        'reason': reason,
        'notes': notes,
      },
    );
    return CashSessionAdjustmentResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
