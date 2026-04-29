import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../models/advance_model.dart';
import '../models/employee_model.dart';
import '../models/payroll_models.dart';

class PayrollService {
  PayrollService._();

  // ─── Employees ───────────────────────────────────────────────────────────────

  static Future<List<Employee>> getEmployees() async {
    debugPrint('Loading employees...');
    final resp = await ApiClient.instance.get('/employees');
    final d = resp.data;
    final list = d is List
        ? d
        : (d['employees'] as List? ??
              d['data'] as List? ??
              d['workers'] as List? ??
              []);
    final employees = list
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList();
    debugPrint('Employees loaded: ${employees.length}');
    return employees;
  }

  static Future<Employee> getEmployee(int id) async {
    final resp = await ApiClient.instance.get('/employees/$id');
    final d = resp.data;
    return Employee.fromJson(
      (d['employee'] ?? d['data'] ?? d) as Map<String, dynamic>,
    );
  }

  static Future<Employee> deactivateEmployee(int id) async {
    final resp = await ApiClient.instance.patch('/employees/$id/deactivate');
    final d = resp.data;
    return Employee.fromJson(
      (d['employee'] ?? d['data'] ?? d) as Map<String, dynamic>,
    );
  }

  static Future<Employee> activateEmployee(int id) async {
    final resp = await ApiClient.instance.patch('/employees/$id/activate');
    final d = resp.data;
    return Employee.fromJson(
      (d['employee'] ?? d['data'] ?? d) as Map<String, dynamic>,
    );
  }

  static Future<Employee> createEmployee({
    required String firstName,
    required String lastName,
    String? phone,
    required String hireDate,
    required double salary,
    required String paymentFrequency,
    required int workDaysPerPeriod,
    required String effectiveFrom,
  }) async {
    final resp = await ApiClient.instance.post(
      '/employees',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        if (phone?.isNotEmpty == true) 'phone': phone,
        'hire_date': hireDate,
        'salary': salary,
        'payment_frequency': paymentFrequency,
        'work_days_per_period': workDaysPerPeriod,
        'effective_from': effectiveFrom,
      },
    );
    final d = resp.data;
    return Employee.fromJson(
      (d['employee'] ?? d['data'] ?? d) as Map<String, dynamic>,
    );
  }

  static Future<List<EmployeeSalary>> getSalaryHistory(int employeeId) async {
    final resp = await ApiClient.instance.get(
      '/employees/$employeeId/salary-history',
    );
    final d = resp.data;
    final list = d is List
        ? d
        : (d['salaries'] as List? ?? d['data'] as List? ?? []);
    return list
        .map((e) => EmployeeSalary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<PayrollPayment>> getEmployeePayrollPayments(
    int employeeId,
  ) async {
    final resp = await ApiClient.instance.get(
      '/employees/$employeeId/payroll-payments',
    );
    final d = resp.data;
    final list = d is List
        ? d
        : (d['payments'] as List? ?? d['data'] as List? ?? []);
    return list
        .map((e) => PayrollPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Advances ────────────────────────────────────────────────────────────────

  static Future<List<Advance>> getAdvances({String? status}) async {
    debugPrint('Loading advances...');
    final resp = await ApiClient.instance.get(
      '/advances',
      queryParameters: status == null ? null : {'status': status},
    );
    final d = resp.data;
    final list = d is List
        ? d
        : (d['advances'] as List? ?? d['data'] as List? ?? []);
    final advances = list
        .map((e) => Advance.fromJson(e as Map<String, dynamic>))
        .toList();
    debugPrint('Advances loaded: ${advances.length}');
    return advances;
  }

  /// Conservado por compatibilidad con pantallas antiguas; ahora usa el
  /// endpoint global de adelantos.
  static Future<List<Advance>> getAdvancesFromEmployees({String? status}) =>
      getAdvances(status: status);

  static Future<List<Advance>> getEmployeeAdvances(int employeeId) async {
    final resp = await ApiClient.instance.get(
      '/employees/$employeeId/advances',
    );
    final d = resp.data;
    final list = d is List
        ? d
        : (d['advances'] as List? ?? d['data'] as List? ?? []);
    return list
        .map((e) => Advance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Advance> getAdvance(int id) async {
    debugPrint('Loading advance detail: $id');
    final resp = await ApiClient.instance.get('/advances/$id');
    final d = resp.data;
    final advance = Advance.fromJson(
      (d['advance'] ?? d['data'] ?? d) as Map<String, dynamic>,
    );
    debugPrint('Advance loaded: ${advance.id} balance ${advance.balance}');
    return advance;
  }

  static Future<Advance> createAdvance(
    int employeeId, {
    required double amount,
    required String advanceDate,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'amount': amount,
      'advance_date': advanceDate,
      if (notes?.isNotEmpty == true) 'notes': notes,
    };
    debugPrint('POST advance payload: $payload');
    final resp = await ApiClient.instance.post(
      '/employees/$employeeId/advances',
      data: payload,
    );
    debugPrint('POST advance response: ${resp.data}');
    final d = resp.data;
    return Advance.fromJson(
      (d['advance'] ?? d['data'] ?? d) as Map<String, dynamic>,
    );
  }

  static Future<void> createAdvancePayment({
    required int advanceId,
    required double amount,
    required String paymentDate,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'amount': amount,
      'payment_type': 'abono_efectivo',
      'payment_date': paymentDate,
      if (notes?.isNotEmpty == true) 'notes': notes,
    };
    debugPrint('POST advance payment payload: $payload');
    final response = await ApiClient.instance.post(
      '/advances/$advanceId/payments',
      data: payload,
    );
    debugPrint('POST advance payment response: ${response.data}');
  }

  // ─── Payroll payments ───────────────────────────────────────────────────────

  static Future<PayrollPreview> getPayrollPreview(int employeeId) async {
    debugPrint('Loading payroll preview for employee: $employeeId');
    final response = await ApiClient.instance.get(
      '/employees/$employeeId/payroll-preview',
    );
    final preview = PayrollPreview.fromJson(
      (response.data['data'] ?? response.data) as Map<String, dynamic>,
    );
    debugPrint(
      'Payroll preview loaded: employee ${preview.employee.id}, '
      'pending ${preview.pendingAdvances.totalBalance}',
    );
    return preview;
  }

  static Future<PayrollPeriod> createPayrollPeriod({
    required String startDate,
    required String endDate,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'start_date': startDate,
      'end_date': endDate,
      if (notes?.isNotEmpty == true) 'notes': notes,
    };
    debugPrint('Creating payroll period payload: $payload');
    final response = await ApiClient.instance.post(
      '/payroll-periods',
      data: payload,
    );
    debugPrint('Payroll period response: ${response.data}');
    return PayrollPeriod.fromJson(
      (response.data['period'] ?? response.data['data'] ?? response.data)
          as Map<String, dynamic>,
    );
  }

  static Future<PayrollPayment> createPayrollPayment({
    required int periodId,
    required int employeeId,
    required int salaryHistoryId,
    required double daysWorked,
    required double advanceDiscount,
    required double extraPayments,
    required double otherDeductions,
    required String paymentDate,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'employee_id': employeeId,
      'salary_history_id': salaryHistoryId,
      'days_worked': daysWorked,
      'advance_discount': advanceDiscount,
      'extra_payments': extraPayments,
      'other_deductions': otherDeductions,
      'payment_date': paymentDate,
      if (notes?.isNotEmpty == true) 'notes': notes,
    };
    debugPrint('Creating payroll payment payload: $payload');
    final response = await ApiClient.instance.post(
      '/payroll-periods/$periodId/payments',
      data: payload,
    );
    debugPrint('Payroll payment response: ${response.data}');
    return PayrollPayment.fromJson(
      (response.data['payment'] ?? response.data['data'] ?? response.data)
          as Map<String, dynamic>,
    );
  }

  static Future<PayrollPayment> confirmPayrollPayment(int paymentId) async {
    debugPrint('Confirming payroll payment id: $paymentId');
    final response = await ApiClient.instance.patch(
      '/payroll-payments/$paymentId/confirm',
    );
    debugPrint('Confirm response: ${response.data}');
    return PayrollPayment.fromJson(
      (response.data['payment'] ?? response.data['data'] ?? response.data)
          as Map<String, dynamic>,
    );
  }

  static Future<PayrollPayment> getPayrollPayment(int paymentId) async {
    final response = await ApiClient.instance.get(
      '/payroll-payments/$paymentId',
    );
    return PayrollPayment.fromJson(
      (response.data['payment'] ?? response.data['data'] ?? response.data)
          as Map<String, dynamic>,
    );
  }
}
