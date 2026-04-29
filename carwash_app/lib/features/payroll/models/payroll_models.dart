import 'advance_model.dart';
import 'employee_model.dart';

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

DateTime _asDate(dynamic value) {
  if (value == null) return DateTime.now();
  return DateTime.parse(value.toString());
}

class PayrollPreview {
  const PayrollPreview({
    required this.employee,
    required this.currentSalary,
    required this.pendingAdvances,
  });

  final PayrollPreviewEmployee employee;
  final EmployeeSalary? currentSalary;
  final PendingAdvancesSummary pendingAdvances;

  factory PayrollPreview.fromJson(Map<String, dynamic> json) {
    final salary = json['current_salary'];
    return PayrollPreview(
      employee: PayrollPreviewEmployee.fromJson(
        (json['employee'] ?? {}) as Map<String, dynamic>,
      ),
      currentSalary: salary is Map<String, dynamic>
          ? EmployeeSalary.fromJson(salary)
          : null,
      pendingAdvances: PendingAdvancesSummary.fromJson(
        (json['pending_advances'] ?? {}) as Map<String, dynamic>,
      ),
    );
  }
}

class PayrollPreviewEmployee {
  const PayrollPreviewEmployee({
    required this.id,
    required this.fullName,
    required this.isActive,
  });

  final int id;
  final String fullName;
  final bool isActive;

  factory PayrollPreviewEmployee.fromJson(Map<String, dynamic> json) {
    return PayrollPreviewEmployee(
      id: _asInt(json['id']),
      fullName: json['full_name']?.toString() ?? '',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
    );
  }
}

class PendingAdvancesSummary {
  const PendingAdvancesSummary({
    required this.totalBalance,
    required this.advances,
  });

  final double totalBalance;
  final List<PayrollAdvancePreview> advances;

  factory PendingAdvancesSummary.fromJson(Map<String, dynamic> json) {
    final rawAdvances = json['advances'] as List? ?? [];
    return PendingAdvancesSummary(
      totalBalance: _asDouble(json['total_balance']),
      advances: rawAdvances
          .map((e) => PayrollAdvancePreview.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PayrollAdvancePreview {
  const PayrollAdvancePreview({
    required this.id,
    required this.amount,
    required this.balance,
    required this.advanceDate,
    required this.status,
  });

  final int id;
  final double amount;
  final double balance;
  final DateTime advanceDate;
  final String status;

  factory PayrollAdvancePreview.fromJson(Map<String, dynamic> json) {
    return PayrollAdvancePreview(
      id: _asInt(json['id']),
      amount: _asDouble(json['amount']),
      balance: _asDouble(json['balance']),
      advanceDate: _asDate(json['advance_date']),
      status: json['status']?.toString() ?? 'pendiente',
    );
  }
}

class PayrollPeriod {
  const PayrollPeriod({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.notes,
  });

  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? notes;

  factory PayrollPeriod.fromJson(Map<String, dynamic> json) {
    return PayrollPeriod(
      id: _asInt(json['id']),
      startDate: _asDate(json['start_date']),
      endDate: _asDate(json['end_date']),
      status: json['status']?.toString() ?? 'abierto',
      notes: json['notes']?.toString(),
    );
  }
}

class PayrollPayment {
  const PayrollPayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.periodId,
    required this.salaryHistoryId,
    required this.baseSalary,
    required this.dailyRate,
    required this.workDaysPerPeriod,
    required this.daysWorked,
    required this.grossAmount,
    required this.extraPayments,
    required this.advanceDiscount,
    required this.otherDeductions,
    required this.netAmount,
    required this.paymentDate,
    required this.status,
    this.notes,
    this.period,
    this.advancePayments = const [],
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final int periodId;
  final int salaryHistoryId;
  final double baseSalary;
  final double dailyRate;
  final int workDaysPerPeriod;
  final double daysWorked;
  final double grossAmount;
  final double extraPayments;
  final double advanceDiscount;
  final double otherDeductions;
  final double netAmount;
  final DateTime paymentDate;
  final String status;
  final String? notes;
  final PayrollPeriod? period;
  final List<AdvancePayment> advancePayments;

  factory PayrollPayment.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>?;
    final firstName = employee?['first_name']?.toString() ?? '';
    final lastName = employee?['last_name']?.toString() ?? '';
    final advancePaymentsJson = json['advance_payments'] as List? ?? [];
    final periodJson = json['period'];

    return PayrollPayment(
      id: _asInt(json['id']),
      employeeId: _asInt(json['employee_id'] ?? employee?['id']),
      employeeName: employee?['full_name']?.toString().isNotEmpty == true
          ? employee!['full_name'].toString()
          : '$firstName $lastName'.trim(),
      periodId: _asInt(json['payroll_period_id'] ?? periodJson?['id']),
      salaryHistoryId: _asInt(json['salary_history_id']),
      baseSalary: _asDouble(json['base_salary']),
      dailyRate: _asDouble(json['daily_rate']),
      workDaysPerPeriod: _asInt(json['work_days_per_period']),
      daysWorked: _asDouble(json['days_worked']),
      grossAmount: _asDouble(json['gross_amount']),
      extraPayments: _asDouble(json['extra_payments']),
      advanceDiscount: _asDouble(json['advance_discount']),
      otherDeductions: _asDouble(json['other_deductions']),
      netAmount: _asDouble(json['net_amount']),
      paymentDate: _asDate(json['payment_date']),
      status: json['status']?.toString() ?? 'borrador',
      notes: json['notes']?.toString(),
      period: periodJson is Map<String, dynamic>
          ? PayrollPeriod.fromJson(periodJson)
          : null,
      advancePayments: advancePaymentsJson
          .map((e) => AdvancePayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
