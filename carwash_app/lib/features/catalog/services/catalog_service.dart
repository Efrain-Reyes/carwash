import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../washes/models/vehicle_type.dart';
import '../../washes/models/wash_service.dart';

class CatalogService {
  CatalogService._();

  static Future<List<VehicleType>> getVehicleTypes({
    bool includeInactive = false,
  }) async {
    debugPrint(
      '[CatalogService] GET /vehicle-types includeInactive: $includeInactive',
    );
    try {
      final response = await ApiClient.instance.get(
        '/vehicle-types',
        queryParameters: includeInactive ? {'include_inactive': 1} : null,
      );
      final data = (response.data as List?) ?? [];
      return data
          .map((e) => VehicleType.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[CatalogService] GET /vehicle-types ← DioException');
      debugPrint('[CatalogService]   status : ${e.response?.statusCode}');
      debugPrint('[CatalogService]   body   : ${e.response?.data}');
      debugPrint('[CatalogService]   message: ${e.message}');
      rethrow;
    }
  }

  static Future<VehicleType> createVehicleType(String name) async {
    final body = {'name': name};
    debugPrint('[CatalogService] POST /vehicle-types → payload: $body');
    try {
      final response = await ApiClient.instance.post(
        '/vehicle-types',
        data: body,
      );
      debugPrint(
        '[CatalogService] POST /vehicle-types ← status: ${response.statusCode}',
      );
      return VehicleType.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[CatalogService] POST /vehicle-types ← DioException');
      debugPrint('[CatalogService]   status : ${e.response?.statusCode}');
      debugPrint('[CatalogService]   body   : ${e.response?.data}');
      debugPrint('[CatalogService]   message: ${e.message}');
      rethrow;
    }
  }

  static Future<VehicleType> toggleVehicleType(int id) async {
    debugPrint('[CatalogService] PATCH /vehicle-types/$id/toggle');
    try {
      final response = await ApiClient.instance.patch(
        '/vehicle-types/$id/toggle',
      );
      debugPrint(
        '[CatalogService] PATCH /vehicle-types/$id/toggle ← status: ${response.statusCode}',
      );
      return VehicleType.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint(
        '[CatalogService] PATCH /vehicle-types/$id/toggle ← DioException',
      );
      debugPrint('[CatalogService]   status : ${e.response?.statusCode}');
      debugPrint('[CatalogService]   body   : ${e.response?.data}');
      debugPrint('[CatalogService]   message: ${e.message}');
      rethrow;
    }
  }

  static Future<List<WashService>> getWashServices({
    int? vehicleTypeId,
    bool includeInactive = false,
  }) async {
    final params = <String, dynamic>{};
    if (vehicleTypeId != null) params['vehicle_type_id'] = vehicleTypeId;
    if (includeInactive) params['include_inactive'] = 1;

    debugPrint('[CatalogService] GET /wash-services params: $params');
    try {
      final response = await ApiClient.instance.get(
        '/wash-services',
        queryParameters: params.isNotEmpty ? params : null,
      );
      final data = (response.data as List?) ?? [];
      return data
          .map((e) => WashService.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[CatalogService] GET /wash-services ← DioException');
      debugPrint('[CatalogService]   status : ${e.response?.statusCode}');
      debugPrint('[CatalogService]   body   : ${e.response?.data}');
      debugPrint('[CatalogService]   message: ${e.message}');
      rethrow;
    }
  }

  static Future<WashService> createWashService({
    required int vehicleTypeId,
    required String name,
    required bool isCustom,
    double? basePrice,
  }) async {
    final body = <String, dynamic>{
      'vehicle_type_id': vehicleTypeId,
      'name': name,
      'is_custom': isCustom,
    };
    if (basePrice != null) body['base_price'] = basePrice;

    debugPrint('[CatalogService] POST /wash-services → payload: $body');
    try {
      final response = await ApiClient.instance.post(
        '/wash-services',
        data: body,
      );
      debugPrint(
        '[CatalogService] POST /wash-services ← status: ${response.statusCode}',
      );
      return WashService.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[CatalogService] POST /wash-services ← DioException');
      debugPrint('[CatalogService]   status : ${e.response?.statusCode}');
      debugPrint('[CatalogService]   body   : ${e.response?.data}');
      debugPrint('[CatalogService]   message: ${e.message}');
      rethrow;
    }
  }

  static Future<WashService> updateWashServicePrice(
    int id, {
    String? name,
    double? basePrice,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (basePrice != null) body['base_price'] = basePrice;

    debugPrint('[CatalogService] PATCH /wash-services/$id → payload: $body');
    try {
      final response = await ApiClient.instance.patch(
        '/wash-services/$id',
        data: body,
      );
      debugPrint(
        '[CatalogService] PATCH /wash-services/$id ← status: ${response.statusCode}',
      );
      return WashService.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[CatalogService] PATCH /wash-services/$id ← DioException');
      debugPrint('[CatalogService]   status : ${e.response?.statusCode}');
      debugPrint('[CatalogService]   body   : ${e.response?.data}');
      debugPrint('[CatalogService]   message: ${e.message}');
      rethrow;
    }
  }

  static Future<WashService> toggleWashService(int id) async {
    debugPrint('[CatalogService] PATCH /wash-services/$id/toggle');
    try {
      final response = await ApiClient.instance.patch(
        '/wash-services/$id/toggle',
      );
      debugPrint(
        '[CatalogService] PATCH /wash-services/$id/toggle ← status: ${response.statusCode}',
      );
      return WashService.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint(
        '[CatalogService] PATCH /wash-services/$id/toggle ← DioException',
      );
      debugPrint('[CatalogService]   status : ${e.response?.statusCode}');
      debugPrint('[CatalogService]   body   : ${e.response?.data}');
      debugPrint('[CatalogService]   message: ${e.message}');
      rethrow;
    }
  }
}
