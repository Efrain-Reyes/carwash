import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../models/vehicle_type.dart';
import '../models/wash_item.dart';

class WashesService {
  WashesService._();

  static Future<List<WashItem>> getToday() async {
    final today = Fmt.dateApi(DateTime.now());
    final response = await ApiClient.instance.get(
      '/washes',
      queryParameters: {'date_from': today, 'date_to': today},
    );
    final data = (response.data['data'] as List?) ?? [];
    return data
        .map((e) => WashItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> getWashes({
    String? dateFrom,
    String? dateTo,
    String? status,
  }) async {
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (status != null) params['status'] = status;

    debugPrint('[WashesService] GET /washes params: $params');

    final response = await ApiClient.instance.get(
      '/washes',
      queryParameters: params.isNotEmpty ? params : null,
    );
    final data = (response.data['data'] as List?) ?? [];
    final total = response.data['total'] as int? ?? 0;
    return {
      'washes': data
          .map((e) => WashItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      'total': total,
    };
  }

  static Future<List<VehicleType>> getVehicleTypes() async {
    final response = await ApiClient.instance.get('/vehicle-types');
    final data = (response.data as List?) ?? [];
    return data
        .map((e) => VehicleType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createWash({
    required int vehicleTypeId,
    required int washServiceId,
    String? customDescription,
    double? price,
    String? notes,
    DateTime? registeredAt,
  }) async {
    final body = <String, dynamic>{
      'vehicle_type_id': vehicleTypeId,
      'wash_service_id': washServiceId,
    };
    if (customDescription != null) {
      body['custom_description'] = customDescription;
    }
    if (price != null) body['price'] = price;
    if (notes != null) body['notes'] = notes;
    if (registeredAt != null) {
      body['registered_at'] = _dateTimeApi(registeredAt);
    }

    debugPrint('[WashesService] POST /washes → payload: $body');

    try {
      final response = await ApiClient.instance.post('/washes', data: body);
      debugPrint(
        '[WashesService] POST /washes ← status: ${response.statusCode}',
      );
      debugPrint('[WashesService] POST /washes ← body: ${response.data}');
    } on DioException catch (e) {
      debugPrint('[WashesService] POST /washes ← DioException');
      debugPrint('[WashesService]   status : ${e.response?.statusCode}');
      debugPrint('[WashesService]   body   : ${e.response?.data}');
      debugPrint('[WashesService]   message: ${e.message}');
      rethrow;
    }
  }

  static Future<WashItem> cancelWash(int id, {String? notes}) async {
    final body = <String, dynamic>{};
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();

    debugPrint('[WashesService] PATCH /washes/$id/cancel notes: $notes');

    try {
      final response = await ApiClient.instance.patch(
        '/washes/$id/cancel',
        data: body.isNotEmpty ? body : null,
      );
      debugPrint(
        '[WashesService] PATCH /washes/$id/cancel ← status: ${response.statusCode}',
      );
      return WashItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[WashesService] PATCH /washes/$id/cancel ← DioException');
      debugPrint('[WashesService]   status : ${e.response?.statusCode}');
      debugPrint('[WashesService]   body   : ${e.response?.data}');
      rethrow;
    }
  }

  static String _dateTimeApi(DateTime date) =>
      '${Fmt.dateApi(date)} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';
}
