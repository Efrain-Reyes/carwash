import 'package:carwash_app/features/washes/models/vehicle_type.dart';
import 'package:carwash_app/features/washes/models/wash_service.dart';
import 'package:carwash_app/features/washes/providers/register_wash_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const completo = WashService(
    id: 1,
    vehicleTypeId: 1,
    name: 'Completo',
    basePrice: 180,
    isCustom: false,
    isActive: true,
  );
  const express = WashService(
    id: 2,
    vehicleTypeId: 1,
    name: 'Express',
    basePrice: 140,
    isCustom: false,
    isActive: true,
  );
  const otro = WashService(
    id: 3,
    vehicleTypeId: 1,
    name: 'Otro',
    isCustom: true,
    isActive: true,
  );
  const cristal = WashService(
    id: 4,
    vehicleTypeId: 1,
    name: 'Cristal perfecto',
    kind: 'extra',
    basePrice: 80,
    isCustom: false,
    isActive: true,
  );
  const calibracion = WashService(
    id: 5,
    vehicleTypeId: 1,
    name: 'Calibración de llantas',
    kind: 'extra',
    basePrice: 30,
    isCustom: false,
    isActive: true,
  );
  const inactivo = WashService(
    id: 6,
    vehicleTypeId: 1,
    name: 'Encerado',
    kind: 'extra',
    basePrice: 99,
    isCustom: false,
    isActive: false,
  );

  late RegisterWashProvider vm;

  setUp(() {
    vm = RegisterWashProvider()
      ..setVehicleTypesForTest([
        const VehicleType(
          id: 1,
          name: 'Carro',
          icon: 'car',
          isActive: true,
          washServices: [
            completo,
            express,
            otro,
            cristal,
            calibracion,
            inactivo,
          ],
        ),
      ]);
    vm.selectVehicleType(vm.vehicleTypes.first);
  });

  test('separa lavados y extras activos', () {
    expect(vm.availableWashes.map((s) => s.name), [
      'Completo',
      'Express',
      'Otro',
    ]);
    expect(vm.availableExtras.map((s) => s.name), [
      'Cristal perfecto',
      'Calibración de llantas',
    ]);
  });

  test('un lavado con varios extras suma el total', () {
    vm.selectWash(completo);
    vm.toggleExtra(cristal);
    vm.toggleExtra(calibracion);

    expect(vm.selectedItems.map((s) => s.name), [
      'Completo',
      'Cristal perfecto',
      'Calibración de llantas',
    ]);
    expect(vm.totalPrice, 290);
    expect(vm.canSave, isTrue);
  });

  test('solo se puede elegir un lavado; elegir otro lo reemplaza', () {
    vm.selectWash(completo);
    vm.selectWash(express);

    expect(vm.selectedWash, express);
    expect(vm.totalPrice, 140);
  });

  test('tocar el mismo lavado lo quita para cobrar solo extras', () {
    vm.selectWash(completo);
    vm.toggleExtra(calibracion);
    vm.selectWash(completo);

    expect(vm.selectedWash, isNull);
    expect(vm.selectedItems, [calibracion]);
    expect(vm.totalPrice, 30);
    expect(vm.canSave, isTrue);
  });

  test('sin nada elegido no se puede guardar', () {
    expect(vm.totalPrice, isNull);
    expect(vm.canSave, isFalse);

    vm.toggleExtra(cristal);
    vm.toggleExtra(cristal);
    expect(vm.canSave, isFalse);
  });

  test('precio libre pide descripción y precio', () {
    vm.selectWash(otro);
    vm.toggleExtra(cristal);
    expect(vm.selectedCustomItems, [otro]);
    expect(vm.canSave, isFalse);

    vm.setCustomDescription(otro, 'Pulido de focos');
    vm.setCustomPrice(otro, '150');
    expect(vm.canSave, isTrue);
    expect(vm.totalPrice, 230);
  });

  test('cambiar de vehículo limpia la selección', () {
    vm.selectWash(completo);
    vm.toggleExtra(cristal);
    vm.selectVehicleType(vm.vehicleTypes.first);

    expect(vm.selectedItems, isEmpty);
  });
}
