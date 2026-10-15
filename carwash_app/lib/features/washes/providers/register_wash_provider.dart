import 'package:flutter/material.dart';
import '../models/vehicle_type.dart';
import '../models/wash_service.dart';
import '../services/washes_service.dart';

/// Registro de lo que se le hizo a un vehículo: como máximo un lavado y los
/// extras que se quieran. También se puede cobrar solo un extra, sin lavado.
class RegisterWashProvider extends ChangeNotifier {
  List<VehicleType> _vehicleTypes = [];
  VehicleType? _selectedVehicleType;
  WashService? _selectedWash;
  final List<WashService> _selectedExtras = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _saveError;
  // Descripción y precio de los servicios de precio libre ("Otro"), por id.
  final Map<int, String> _customDescriptions = {};
  final Map<int, double?> _customPrices = {};
  DateTime? _registeredAt;

  List<VehicleType> get vehicleTypes => _vehicleTypes;
  VehicleType? get selectedVehicleType => _selectedVehicleType;
  WashService? get selectedWash => _selectedWash;
  List<WashService> get selectedExtras => List.unmodifiable(_selectedExtras);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  String? get saveError => _saveError;
  DateTime? get registeredAt => _registeredAt;
  bool get hasCustomDate => _registeredAt != null;

  List<WashService> get _activeServices =>
      _selectedVehicleType?.washServices.where((s) => s.isActive).toList() ??
      [];

  List<WashService> get availableWashes =>
      _activeServices.where((s) => !s.isExtra).toList();

  List<WashService> get availableExtras =>
      _activeServices.where((s) => s.isExtra).toList();

  /// Lo que se va a cobrar, en orden: primero el lavado y luego los extras.
  List<WashService> get selectedItems => [?_selectedWash, ..._selectedExtras];

  List<WashService> get selectedCustomItems =>
      selectedItems.where((s) => s.isCustom).toList();

  bool isExtraSelected(WashService service) =>
      _selectedExtras.any((s) => s.id == service.id);

  double? priceOf(WashService service) =>
      service.isCustom ? _customPrices[service.id] : service.basePrice;

  double? get totalPrice {
    if (selectedItems.isEmpty) return null;
    return selectedItems.fold<double>(0, (sum, s) => sum + (priceOf(s) ?? 0));
  }

  bool get canSave {
    if (selectedItems.isEmpty) return false;
    return selectedCustomItems.every((s) {
      final price = _customPrices[s.id];
      return (_customDescriptions[s.id] ?? '').trim().isNotEmpty &&
          price != null &&
          price > 0;
    });
  }

  @visibleForTesting
  void setVehicleTypesForTest(List<VehicleType> types) {
    _vehicleTypes = types;
    notifyListeners();
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
    _selectedWash = null;
    _selectedExtras.clear();
    _customDescriptions.clear();
    _customPrices.clear();
    _saveError = null;
    notifyListeners();
  }

  /// Elige el lavado; tocar el mismo otra vez lo quita (para cobrar solo extras).
  void selectWash(WashService service) {
    if (_selectedWash?.id == service.id) {
      _forgetCustom(service);
      _selectedWash = null;
    } else {
      if (_selectedWash != null) _forgetCustom(_selectedWash!);
      _selectedWash = service;
    }
    _saveError = null;
    notifyListeners();
  }

  void toggleExtra(WashService service) {
    if (isExtraSelected(service)) {
      _selectedExtras.removeWhere((s) => s.id == service.id);
      _forgetCustom(service);
    } else {
      _selectedExtras.add(service);
    }
    _saveError = null;
    notifyListeners();
  }

  void setCustomDescription(WashService service, String value) {
    _customDescriptions[service.id] = value;
    notifyListeners();
  }

  void setCustomPrice(WashService service, String value) {
    _customPrices[service.id] = double.tryParse(value.trim());
    notifyListeners();
  }

  void setRegisteredAt(DateTime? value) {
    _registeredAt = value;
    _saveError = null;
    notifyListeners();
  }

  void _forgetCustom(WashService service) {
    _customDescriptions.remove(service.id);
    _customPrices.remove(service.id);
  }

  Future<bool> save() async {
    if (!canSave || _saving) return false;
    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      await WashesService.createWashes(
        vehicleTypeId: _selectedVehicleType!.id,
        items: [
          for (final s in selectedItems)
            WashItemRequest(
              washServiceId: s.id,
              price: s.isCustom ? _customPrices[s.id] : null,
              customDescription: s.isCustom
                  ? _customDescriptions[s.id]!.trim()
                  : null,
            ),
        ],
        registeredAt: _registeredAt,
      );
      _saving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _saveError =
          'No se puede registrar en este momento. Contacte al administrador.';
      _saving = false;
      notifyListeners();
      return false;
    }
  }
}
