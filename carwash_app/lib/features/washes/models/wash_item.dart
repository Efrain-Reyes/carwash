class WashItem {
  final int id;
  final String vehicleTypeName;
  final String serviceName;
  final String? customDescription;
  final double price;
  final String status;
  final DateTime registeredAt;
  final String? userName;
  final String? notes;

  const WashItem({
    required this.id,
    required this.vehicleTypeName,
    required this.serviceName,
    this.customDescription,
    required this.price,
    required this.status,
    required this.registeredAt,
    this.userName,
    this.notes,
  });

  factory WashItem.fromJson(Map<String, dynamic> json) {
    return WashItem(
      id:               json['id'] as int,
      vehicleTypeName:  (json['vehicle_type'] as Map?)?['name']?.toString() ?? '',
      serviceName:      (json['wash_service'] as Map?)?['name']?.toString() ?? '',
      customDescription: json['custom_description'] as String?,
      price:            double.parse(json['price'].toString()),
      status:           json['status'] as String,
      registeredAt:     DateTime.parse(json['registered_at'] as String),
      userName:         (json['user'] as Map?)?['name']?.toString(),
      notes:            json['notes'] as String?,
    );
  }

  String get displayService =>
      (customDescription?.isNotEmpty ?? false) ? customDescription! : serviceName;

  String get timeFormatted {
    final local = registeredAt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dateTimeFormatted {
    final local = registeredAt.toLocal();
    final day   = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final h     = local.hour.toString().padLeft(2, '0');
    final m     = local.minute.toString().padLeft(2, '0');
    return '$day/$month $h:$m';
  }

  bool get isCompleted => status == 'completado';
  bool get isAnulado   => status == 'anulado';
}
