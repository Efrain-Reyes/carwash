double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ??
      double.tryParse(value.toString())?.toInt() ??
      0;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class CashUserRef {
  final int id;
  final String name;

  const CashUserRef({required this.id, required this.name});

  factory CashUserRef.fromJson(Map<String, dynamic> json) {
    return CashUserRef(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class CashSessionModel {
  final int id;
  final double openingAmount;
  final double? expectedClosingAmount;
  final double? countedClosingAmount;
  final double? difference;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String status;
  final CashUserRef? openedBy;
  final CashUserRef? closedBy;
  final String? notes;
  final bool needsReview;
  final List<CashSessionAdjustmentModel> adjustments;

  const CashSessionModel({
    required this.id,
    required this.openingAmount,
    this.expectedClosingAmount,
    this.countedClosingAmount,
    this.difference,
    this.openedAt,
    this.closedAt,
    required this.status,
    this.openedBy,
    this.closedBy,
    this.notes,
    required this.needsReview,
    this.adjustments = const [],
  });

  factory CashSessionModel.fromJson(Map<String, dynamic> json) {
    final openedBy = json['opened_by'];
    final closedBy = json['closed_by'];
    final adjustments = json['adjustments'];

    return CashSessionModel(
      id: _asInt(json['id']),
      openingAmount: _asDouble(
        json['opening_amount'] ?? json['saldo_inicial_caja'],
      ),
      expectedClosingAmount:
          (json['expected_closing_amount'] ?? json['saldo_final_estimado']) ==
              null
          ? null
          : _asDouble(
              json['expected_closing_amount'] ?? json['saldo_final_estimado'],
            ),
      countedClosingAmount:
          (json['counted_closing_amount'] ?? json['efectivo_contado']) == null
          ? null
          : _asDouble(
              json['counted_closing_amount'] ?? json['efectivo_contado'],
            ),
      difference: (json['difference'] ?? json['diferencia_caja']) == null
          ? null
          : _asDouble(json['difference'] ?? json['diferencia_caja']),
      openedAt: _asDate(json['opened_at']),
      closedAt: _asDate(json['closed_at']),
      status: json['status']?.toString() ?? '',
      openedBy: openedBy is Map<String, dynamic>
          ? CashUserRef.fromJson(openedBy)
          : null,
      closedBy: closedBy is Map<String, dynamic>
          ? CashUserRef.fromJson(closedBy)
          : null,
      notes: json['notes']?.toString(),
      needsReview: json['needs_review'] == true,
      adjustments: adjustments is List
          ? adjustments
                .map(
                  (item) => CashSessionAdjustmentModel.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList()
          : const [],
    );
  }

  bool get isClosed => status == 'cerrada';
  bool get isOpen => status == 'abierta';
}

class CashSessionAdjustmentModel {
  final int id;
  final int cashSessionId;
  final CashUserRef? user;
  final double? oldCountedClosingAmount;
  final double newCountedClosingAmount;
  final double? oldDifference;
  final double newDifference;
  final String? oldNotes;
  final String? newNotes;
  final String reason;
  final DateTime? createdAt;

  const CashSessionAdjustmentModel({
    required this.id,
    required this.cashSessionId,
    this.user,
    this.oldCountedClosingAmount,
    required this.newCountedClosingAmount,
    this.oldDifference,
    required this.newDifference,
    this.oldNotes,
    this.newNotes,
    required this.reason,
    this.createdAt,
  });

  factory CashSessionAdjustmentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    return CashSessionAdjustmentModel(
      id: _asInt(json['id']),
      cashSessionId: _asInt(json['cash_session_id']),
      user: user is Map<String, dynamic> ? CashUserRef.fromJson(user) : null,
      oldCountedClosingAmount: json['old_counted_closing_amount'] == null
          ? null
          : _asDouble(json['old_counted_closing_amount']),
      newCountedClosingAmount: _asDouble(json['new_counted_closing_amount']),
      oldDifference: json['old_difference'] == null
          ? null
          : _asDouble(json['old_difference']),
      newDifference: _asDouble(json['new_difference']),
      oldNotes: json['old_notes']?.toString(),
      newNotes: json['new_notes']?.toString(),
      reason: json['reason']?.toString() ?? '',
      createdAt: _asDate(json['created_at']),
    );
  }
}

class CashSessionAdjustmentResult {
  final CashSessionModel cashSession;
  final bool nextSessionUpdated;
  final String? warning;

  const CashSessionAdjustmentResult({
    required this.cashSession,
    required this.nextSessionUpdated,
    this.warning,
  });

  factory CashSessionAdjustmentResult.fromJson(Map<String, dynamic> json) {
    return CashSessionAdjustmentResult(
      cashSession: CashSessionModel.fromJson(
        json['cash_session'] as Map<String, dynamic>,
      ),
      nextSessionUpdated: json['next_session_updated'] == true,
      warning: json['warning']?.toString(),
    );
  }
}
