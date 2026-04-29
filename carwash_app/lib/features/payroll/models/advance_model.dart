class Advance {
  final int id;
  final int employeeId;
  final String employeeName;
  final String? registeredByName;
  final double amount;
  final double balance;
  final String status;
  final DateTime advanceDate;
  final String? notes;
  final List<AdvancePayment> payments;

  const Advance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.registeredByName,
    required this.amount,
    required this.balance,
    required this.status,
    required this.advanceDate,
    this.notes,
    this.payments = const [],
  });

  bool get isPending => status == 'pendiente';
  bool get isPartial => status == 'parcialmente_pagado';
  bool get isPaid => status == 'pagado';
  bool get isAnulado => status == 'anulado';

  double get progress =>
      amount > 0 ? ((amount - balance) / amount).clamp(0.0, 1.0) : 0.0;

  factory Advance.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>?;
    final firstName = emp?['first_name']?.toString() ?? '';
    final lastName = emp?['last_name']?.toString() ?? '';
    final registeredBy = json['registered_by'] as Map<String, dynamic>?;
    final paymentsJson = json['payments'] as List? ?? [];
    return Advance(
      id: json['id'] as int,
      employeeId: emp?['id'] as int? ?? json['employee_id'] as int? ?? 0,
      employeeName: emp != null ? '$firstName $lastName'.trim() : '',
      registeredByName: registeredBy?['name']?.toString(),
      amount: double.parse(json['amount'].toString()),
      balance: double.parse(json['balance'].toString()),
      status: json['status'] as String,
      advanceDate: DateTime.parse(json['advance_date'] as String),
      notes: json['notes'] as String?,
      payments: paymentsJson
          .map((e) => AdvancePayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AdvancePayment {
  final int id;
  final double amount;
  final String paymentType;
  final DateTime paymentDate;
  final String? notes;
  final String? registeredByName;

  const AdvancePayment({
    required this.id,
    required this.amount,
    required this.paymentType,
    required this.paymentDate,
    this.notes,
    this.registeredByName,
  });

  String get paymentTypeLabel => switch (paymentType) {
    'abono_efectivo' => 'Abono en efectivo',
    'descuento_nomina' => 'Descuento de nómina',
    'ajuste_manual' => 'Ajuste manual',
    _ => paymentType,
  };

  factory AdvancePayment.fromJson(Map<String, dynamic> json) {
    final registeredBy = json['registered_by'] as Map<String, dynamic>?;
    return AdvancePayment(
      id: json['id'] as int,
      amount: double.parse(json['amount'].toString()),
      paymentType: json['payment_type'] as String? ?? 'abono_efectivo',
      paymentDate: DateTime.parse(json['payment_date'] as String),
      notes: json['notes'] as String?,
      registeredByName: registeredBy?['name']?.toString(),
    );
  }
}
