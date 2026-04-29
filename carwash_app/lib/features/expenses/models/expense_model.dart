class ExpenseItem {
  final int id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final double subtotal;
  final double taxAmount;
  final double total;

  const ExpenseItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id:          json['id'] as int,
      description: json['description'] as String,
      quantity:    double.parse(json['quantity'].toString()),
      unitPrice:   double.parse(json['unit_price'].toString()),
      taxRate:     double.parse(json['tax_rate']?.toString() ?? '0'),
      subtotal:    double.parse(json['subtotal'].toString()),
      taxAmount:   double.parse(json['tax_amount'].toString()),
      total:       double.parse(json['total'].toString()),
    );
  }
}

class Expense {
  final int id;
  final String supplierName;
  final String? invoiceNumber;
  final bool isInternalInvoice;
  final int? internalCorrelative;
  final double subtotal;
  final double taxAmount;
  final double total;
  final DateTime expenseDate;
  final String? notes;
  final String status;
  final String? userName;
  final List<ExpenseItem> items;

  const Expense({
    required this.id,
    required this.supplierName,
    this.invoiceNumber,
    required this.isInternalInvoice,
    this.internalCorrelative,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.expenseDate,
    this.notes,
    required this.status,
    this.userName,
    this.items = const [],
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id:                  json['id'] as int,
      supplierName:        (json['supplier'] as Map?)?['name']?.toString() ?? '',
      invoiceNumber:       json['invoice_number'] as String?,
      isInternalInvoice:   json['is_internal_invoice'] as bool? ?? false,
      internalCorrelative: json['internal_correlative'] as int?,
      subtotal:            double.parse(json['subtotal']?.toString() ?? '0'),
      taxAmount:           double.parse(json['tax_amount']?.toString() ?? '0'),
      total:               double.parse(json['total']?.toString() ?? '0'),
      expenseDate:         DateTime.parse(json['expense_date'] as String),
      notes:               json['notes'] as String?,
      status:              json['status'] as String,
      userName:            (json['user'] as Map?)?['name']?.toString(),
      items:               (json['items'] as List? ?? [])
                               .map((e) => ExpenseItem.fromJson(e as Map<String, dynamic>))
                               .toList(),
    );
  }

  String get invoiceDisplay {
    if (isInternalInvoice) {
      final n = internalCorrelative?.toString().padLeft(4, '0') ?? '?';
      return 'INT-$n';
    }
    return invoiceNumber ?? '—';
  }

  String get invoiceLabel =>
      isInternalInvoice ? 'Correlativo interno' : 'Factura';

  bool get isActive => status == 'activo';
}
