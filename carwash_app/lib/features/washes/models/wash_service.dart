class WashService {
  final int id;
  final int vehicleTypeId;
  final String name;
  final double? basePrice;
  final bool isCustom;
  final bool isActive;

  const WashService({
    required this.id,
    required this.vehicleTypeId,
    required this.name,
    this.basePrice,
    required this.isCustom,
    required this.isActive,
  });

  factory WashService.fromJson(Map<String, dynamic> json) {
    return WashService(
      id: json['id'] as int,
      vehicleTypeId: json['vehicle_type_id'] as int,
      name: json['name'] as String,
      basePrice: json['base_price'] != null
          ? double.parse(json['base_price'].toString())
          : null,
      isCustom: json['is_custom'] as bool,
      isActive: json['is_active'] as bool,
    );
  }
}
