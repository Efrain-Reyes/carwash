import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../models/expense_model.dart';
import '../models/supplier_model.dart';

class ExpenseService {
  ExpenseService._();

  static Future<List<Supplier>> getSuppliers() async {
    final response = await ApiClient.instance.get('/suppliers');
    final data = (response.data as List?) ?? [];
    return data.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Supplier> createSupplier(String name, {String? contact}) async {
    final body = <String, dynamic>{'name': name.trim()};
    if (contact != null && contact.trim().isNotEmpty) body['contact'] = contact.trim();
    debugPrint('[ExpenseService] POST /suppliers name: $name');
    final response = await ApiClient.instance.post('/suppliers', data: body);
    return Supplier.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> getExpenses({
    String? dateFrom,
    String? dateTo,
    String? status,
  }) async {
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null)   params['date_to']   = dateTo;
    if (status != null)   params['status']    = status;

    debugPrint('[ExpenseService] GET /expenses params: $params');
    final response = await ApiClient.instance.get(
      '/expenses',
      queryParameters: params.isNotEmpty ? params : null,
    );
    final data  = (response.data['data'] as List?) ?? [];
    final total = response.data['total'] as int? ?? 0;
    return {
      'expenses': data.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList(),
      'total': total,
    };
  }

  static Future<Expense> getExpense(int id) async {
    final response = await ApiClient.instance.get('/expenses/$id');
    return Expense.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Expense> createExpense({
    required int supplierId,
    required bool isInternalInvoice,
    String? invoiceNumber,
    required String expenseDate,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final body = <String, dynamic>{
      'supplier_id':         supplierId,
      'is_internal_invoice': isInternalInvoice,
      'expense_date':        expenseDate,
      'items':               items,
    };
    if (!isInternalInvoice && invoiceNumber != null) {
      body['invoice_number'] = invoiceNumber.trim();
    }
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();

    debugPrint('[ExpenseService] POST /expenses supplier: $supplierId items: ${items.length}');

    try {
      final response = await ApiClient.instance.post('/expenses', data: body);
      debugPrint('[ExpenseService] POST /expenses ← ${response.statusCode}');
      return Expense.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[ExpenseService] POST /expenses ← DioException ${e.response?.statusCode}');
      debugPrint('[ExpenseService]   body: ${e.response?.data}');
      rethrow;
    }
  }
}
