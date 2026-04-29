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

class AccountingReport {
  final AccountingPeriod periodo;
  final AccountingSummary resumen;
  final AccountingWashes lavados;
  final AccountingExpensesDetail gastosDetalle;

  const AccountingReport({
    required this.periodo,
    required this.resumen,
    required this.lavados,
    required this.gastosDetalle,
  });

  bool get hasMovements =>
      resumen.ingresosLavados != 0 ||
      resumen.totalGastos != 0 ||
      resumen.sueldoDevengado != 0 ||
      resumen.nominaNetaPagada != 0 ||
      resumen.adelantosEntregados != 0 ||
      resumen.abonosRecibidos != 0 ||
      lavados.cantidad > 0 ||
      gastosDetalle.porProveedor.isNotEmpty ||
      gastosDetalle.porItem.isNotEmpty;

  factory AccountingReport.fromJson(Map<String, dynamic> json) {
    final resumen = json['resumen'];
    final lavados = json['lavados'];
    final gastos = json['gastos_detalle'];
    final periodo = json['periodo'];

    return AccountingReport(
      periodo: AccountingPeriod.fromJson(
        periodo is Map<String, dynamic> ? periodo : const {},
      ),
      resumen: AccountingSummary.fromJson(
        resumen is Map<String, dynamic> ? resumen : const {},
      ),
      lavados: AccountingWashes.fromJson(
        lavados is Map<String, dynamic> ? lavados : const {},
      ),
      gastosDetalle: AccountingExpensesDetail.fromJson(
        gastos is Map<String, dynamic> ? gastos : const {},
      ),
    );
  }
}

class AccountingPeriod {
  final DateTime? desde;
  final DateTime? hasta;

  const AccountingPeriod({this.desde, this.hasta});

  factory AccountingPeriod.fromJson(Map<String, dynamic> json) {
    return AccountingPeriod(
      desde: _asDate(json['desde'] ?? json['date_from']),
      hasta: _asDate(json['hasta'] ?? json['date_to']),
    );
  }
}

class AccountingSummary {
  final double ingresosLavados;
  final double totalGastos;
  final double sueldoDevengado;
  final double nominaNetaPagada;
  final double adelantosEntregados;
  final double abonosRecibidos;
  final double utilidadOperativa;
  final double flujoEfectivoEstimado;

  const AccountingSummary({
    required this.ingresosLavados,
    required this.totalGastos,
    required this.sueldoDevengado,
    required this.nominaNetaPagada,
    required this.adelantosEntregados,
    required this.abonosRecibidos,
    required this.utilidadOperativa,
    required this.flujoEfectivoEstimado,
  });

  factory AccountingSummary.fromJson(Map<String, dynamic> json) {
    return AccountingSummary(
      ingresosLavados: _asDouble(json['ingresos_lavados']),
      totalGastos: _asDouble(json['total_gastos']),
      sueldoDevengado: _asDouble(json['sueldo_devengado']),
      nominaNetaPagada: _asDouble(json['nomina_neta_pagada']),
      adelantosEntregados: _asDouble(json['adelantos_entregados']),
      abonosRecibidos: _asDouble(json['abonos_recibidos_trabajadores']),
      utilidadOperativa: _asDouble(json['utilidad_operativa']),
      flujoEfectivoEstimado: _asDouble(json['flujo_efectivo_estimado']),
    );
  }
}

class AccountingWashes {
  final int cantidad;
  final List<WashesByVehicle> porVehiculo;
  final List<WashesByService> porServicio;

  const AccountingWashes({
    required this.cantidad,
    required this.porVehiculo,
    required this.porServicio,
  });

  factory AccountingWashes.fromJson(Map<String, dynamic> json) {
    final byVehicle = json['por_vehiculo'] as List? ?? [];
    final byService = json['por_servicio'] as List? ?? [];
    return AccountingWashes(
      cantidad: _asInt(json['cantidad']),
      porVehiculo: byVehicle
          .map((e) => WashesByVehicle.fromJson(e as Map<String, dynamic>))
          .toList(),
      porServicio: byService
          .map((e) => WashesByService.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WashesByVehicle {
  final String tipo;
  final int cantidad;
  final double total;

  const WashesByVehicle({
    required this.tipo,
    required this.cantidad,
    required this.total,
  });

  factory WashesByVehicle.fromJson(Map<String, dynamic> json) {
    return WashesByVehicle(
      tipo: json['tipo']?.toString() ?? 'Sin tipo',
      cantidad: _asInt(json['cantidad']),
      total: _asDouble(json['total']),
    );
  }
}

class WashesByService {
  final String vehiculo;
  final String servicio;
  final int cantidad;
  final double total;

  const WashesByService({
    required this.vehiculo,
    required this.servicio,
    required this.cantidad,
    required this.total,
  });

  String get label => vehiculo.isEmpty ? servicio : '$vehiculo · $servicio';

  factory WashesByService.fromJson(Map<String, dynamic> json) {
    return WashesByService(
      vehiculo: json['vehiculo']?.toString() ?? '',
      servicio: json['servicio']?.toString() ?? 'Sin servicio',
      cantidad: _asInt(json['cantidad']),
      total: _asDouble(json['total']),
    );
  }
}

class AccountingExpensesDetail {
  final List<ExpensesBySupplier> porProveedor;
  final List<ExpensesByItem> porItem;

  const AccountingExpensesDetail({
    required this.porProveedor,
    required this.porItem,
  });

  factory AccountingExpensesDetail.fromJson(Map<String, dynamic> json) {
    final bySupplier = json['por_proveedor'] as List? ?? [];
    final byItem = json['por_item'] as List? ?? [];
    return AccountingExpensesDetail(
      porProveedor: bySupplier
          .map((e) => ExpensesBySupplier.fromJson(e as Map<String, dynamic>))
          .toList(),
      porItem: byItem
          .map((e) => ExpensesByItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExpensesBySupplier {
  final String proveedor;
  final int facturas;
  final double total;

  const ExpensesBySupplier({
    required this.proveedor,
    required this.facturas,
    required this.total,
  });

  factory ExpensesBySupplier.fromJson(Map<String, dynamic> json) {
    return ExpensesBySupplier(
      proveedor: json['proveedor']?.toString() ?? 'Sin proveedor',
      facturas: _asInt(json['facturas']),
      total: _asDouble(json['total']),
    );
  }
}

class ExpensesByItem {
  final String descripcion;
  final double cantidad;
  final double total;

  const ExpensesByItem({
    required this.descripcion,
    required this.cantidad,
    required this.total,
  });

  factory ExpensesByItem.fromJson(Map<String, dynamic> json) {
    return ExpensesByItem(
      descripcion: json['descripcion']?.toString() ?? 'Sin descripción',
      cantidad: _asDouble(json['cantidad']),
      total: _asDouble(json['total']),
    );
  }
}
