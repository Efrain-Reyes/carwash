import 'package:flutter/material.dart';
import '../models/vehicle_type.dart';
import '../models/wash_service.dart';
import '../services/washes_service.dart';

class RegisterWashProvider extends ChangeNotifier {
  List<VehicleType> _vehicleTypes = [];
  VehicleType? _selectedVehicleType;
  WashService? _selectedService;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _saveError;
  String _customDescription = '';
  double? _customPrice;
  DateTime? _registeredAt;

  List<VehicleType> get vehicleTypes => _vehicleTypes;
  VehicleType? get selectedVehicleType => _selectedVehicleType;
  WashService? get selectedService => _selectedService;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  String? get saveError => _saveError;
  DateTime? get registeredAt => _registeredAt;
  bool get hasCustomDate => _registeredAt != null;

  double? get totalPrice {
    if (_selectedService == null) return null;
    if (_selectedService!.isCustom) return _customPrice;
    return _selectedService!.basePrice;
  }

  bool get canSave {
    if (_selectedService == null) return false;
    if (_selectedService!.isCustom) {
      return _customDescription.trim().isNotEmpty &&
          _customPrice != null &&
          _customPrice! > 0;
    }
    return true;
  }

  Future<void> loadVehicleTypes() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _vehicleTypes = await WashesService.getVehicleTypes();
    } catch (_) {
      _error =
          'No se pudo cargar los tipos de vehículo.\nVerifica tu red e intenta de nuevo.';
    }
    _loading = false;
    notifyListeners();
  }

  void selectVehicleType(VehicleType type) {
    _selectedVehicleType = type;
    _selectedService = null;
    _customDescription = '';
    _customPrice = null;
    _saveError = null;
    notifyListeners();
  }

  void selectService(WashService service) {
    _selectedService = service;
    _customDescription = '';
    _customPrice = null;
    _saveError = null;
    notifyListeners();
  }

  void setCustomDescription(String value) {
    _customDescription = value;
    notifyListeners();
  }

  void setCustomPrice(String value) {
    _customPrice = double.tryParse(value.trim());
    notifyListeners();
  }

  void setRegisteredAt(DateTime? value) {
    _registeredAt = value;
    _saveError = null;
    notifyListeners();
  }

  Future<bool> save() async {
    if (!canSave || _saving) return false;
    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      await WashesService.createWash(
        vehicleTypeId: _selectedVehicleType!.id,
        washServiceId: _selectedService!.id,
        customDescription: _selectedService!.isCustom
            ? _customDescription.trim()
            : null,
        price: _selectedService!.isCustom ? _customPrice : null,
        registeredAt: _registeredAt,
      );
      _saving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _saveError =
          'No se puede registrar el lavado en este momento. Contacte al administrador.';
      _saving = false;
      notifyListeners();
      return false;
    }
  }
}
