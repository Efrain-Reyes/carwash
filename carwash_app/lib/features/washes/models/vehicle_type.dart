import 'wash_service.dart';

class VehicleType {
  final int id;
  final String name;
  final bool isActive;
  final List<WashService> washServices;

  const VehicleType({
    required this.id,
    required this.name,
    required this.isActive,
    required this.washServices,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] as int,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
      washServices: (json['wash_services'] as List? ?? [])
          .map((e) => WashService.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
