import 'package:flutter/material.dart';

/// Icono de un tipo de vehículo. La clave (`icon`) se elige en el panel web
/// (VehicleType::ICONS en el backend). Si no viene, se adivina por el nombre
/// como se hacía antes.
IconData vehicleIcon(String? icon, {String name = ''}) {
  switch (icon) {
    case 'car':
      return Icons.directions_car_rounded;
    case 'pickup':
      return Icons.directions_car_filled_rounded;
    case 'van':
      return Icons.airport_shuttle_rounded;
    case 'motorcycle':
      return Icons.two_wheeler_rounded;
    case 'mototaxi':
      return Icons.electric_rickshaw_rounded;
    case 'truck':
      return Icons.local_shipping_rounded;
    case 'bus':
      return Icons.directions_bus_rounded;
    case 'tractor':
      return Icons.agriculture_rounded;
    case 'bike':
      return Icons.pedal_bike_rounded;
  }

  final n = name.toLowerCase();
  if (n.contains('moto')) return Icons.two_wheeler_rounded;
  if (n.contains('camión') || n.contains('camion') || n.contains('truck')) {
    return Icons.local_shipping_rounded;
  }
  return Icons.directions_car_rounded;
}
