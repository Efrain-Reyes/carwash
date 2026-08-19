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
  final AccountingCash? caja;
  final AccountingWashes lavados;
  final AccountingExpensesDetail gastosDetalle;

  const AccountingReport({
    required this.periodo,
    required this.resumen,
    this.caja,
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
      caja != null ||
      lavados.cantidad > 0 ||
      gastosDetalle.porProveedor.isNotEmpty ||
      gastosDetalle.porItem.isNotEmpty;

  factory AccountingReport.fromJson(Map<String, dynamic> json) {
    final resumen = json['resumen'];
    final lavados = json['lavados'];
    final gastos = json['gastos_detalle'];
    final periodo = json['periodo'];
    final caja = json['caja'];

    return AccountingReport(
      periodo: AccountingPeriod.fromJson(
        periodo is Map<String, dynamic> ? periodo : const {},
      ),
      resumen: AccountingSummary.fromJson(
        resumen is Map<String, dynamic> ? resumen : const {},
      ),
      caja: caja is Map<String, dynamic> ? AccountingCash.fromJson(caja) : null,
      lavados: AccountingWashes.fromJson(
        lavados is Map<String, dynamic> ? lavados : const {},
      ),
      gastosDetalle: AccountingExpensesDetail.fromJson(
        gastos is Map<String, dynamic> ? gastos : const {},
      ),
    );
  }
}

class AccountingCash {
  final int id;
  final String status;
  final double saldoInicialCaja;
  final double movimientoNetoEfectivo;
  final double saldoFinalEstimado;
  final double? efectivoContado;
  final double? diferenciaCaja;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String? notes;

  const AccountingCash({
    required this.id,
    required this.status,
    required this.saldoInicialCaja,
    required this.movimientoNetoEfectivo,
    required this.saldoFinalEstimado,
    this.efectivoContado,
    this.diferenciaCaja,
    this.openedAt,
    this.closedAt,
    this.notes,
  });

  bool get isClosed => status == 'cerrada';
  bool get isOpen => status == 'abierta';

  factory AccountingCash.fromJson(Map<String, dynamic> json) {
    return AccountingCash(
      id: _asInt(json['id']),
      status: json['status']?.toString() ?? '',
      saldoInicialCaja: _asDouble(
        json['saldo_inicial_caja'] ?? json['opening_amount'],
      ),
      movimientoNetoEfectivo: _asDouble(json['movimiento_neto_efectivo']),
      saldoFinalEstimado: _asDouble(
        json['saldo_final_estimado'] ?? json['expected_closing_amount'],
      ),
      efectivoContado:
          (json['efectivo_contado'] ?? json['counted_closing_amount']) == null
          ? null
          : _asDouble(
              json['efectivo_contado'] ?? json['counted_closing_amount'],
            ),
      diferenciaCaja: (json['diferencia_caja'] ?? json['difference']) == null
          ? null
          : _asDouble(json['diferencia_caja'] ?? json['difference']),
      openedAt: _asDate(json['opened_at']),
      closedAt: _asDate(json['closed_at']),
      notes: json['notes']?.toString(),
    );
  }
}

class CurrentCashSessionResponse {
  final AccountingCash? cashSession;
  final String? message;
  final bool requiresFirstCashSession;
  final bool pendingClosure;
  final bool openedAutomatically;
  final PendingCashSummary? pendingSummary;

  const CurrentCashSessionResponse({
    required this.cashSession,
    this.message,
    required this.requiresFirstCashSession,
    required this.pendingClosure,
    required this.openedAutomatically,
    this.pendingSummary,
  });

  factory CurrentCashSessionResponse.fromJson(Map<String, dynamic> json) {
    final cashSession = json['cash_session'];
    final pendingSummary = json['pending_summary'];
    return CurrentCashSessionResponse(
      cashSession: cashSession is Map<String, dynamic>
          ? AccountingCash.fromJson(cashSession)
          : null,
      message: json['message']?.toString(),
      requiresFirstCashSession: json['requires_first_cash_session'] == true,
      pendingClosure: json['pending_closure'] == true,
      openedAutomatically: json['opened_automatically'] == true,
      pendingSummary: pendingSummary is Map<String, dynamic>
          ? PendingCashSummary.fromJson(pendingSummary)
          : null,
    );
  }
}

/// Desglose de días/lavados pendientes de una sesión de caja abierta hace más
/// de un día — permite mostrar en el resumen de cierre cuánto llevaba
/// acumulado, en vez de solo los datos de hoy.
class PendingCashSummary {
  final DateTime? fechaApertura;
  final int diasAbiertos;
  final int cantidadLavados;
  final double montoLavados;
  final List<PendingCashDay> porDia;

  const PendingCashSummary({
    this.fechaApertura,
    required this.diasAbiertos,
    required this.cantidadLavados,
    required this.montoLavados,
    required this.porDia,
  });

  factory PendingCashSummary.fromJson(Map<String, dynamic> json) {
    final porDia = json['por_dia'] as List? ?? [];
    return PendingCashSummary(
      fechaApertura: _asDate(json['fecha_apertura']),
      diasAbiertos: _asInt(json['dias_abiertos']),
      cantidadLavados: _asInt(json['cantidad_lavados']),
      montoLavados: _asDouble(json['monto_lavados']),
      porDia: porDia
          .map((e) => PendingCashDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PendingCashDay {
  final DateTime? fecha;
  final int cantidad;
  final double total;

  const PendingCashDay({this.fecha, required this.cantidad, required this.total});

  factory PendingCashDay.fromJson(Map<String, dynamic> json) {
    return PendingCashDay(
      fecha: _asDate(json['fecha']),
      cantidad: _asInt(json['cantidad']),
      total: _asDouble(json['total']),
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
  final double movimientoNetoEfectivo;
  final double flujoEfectivoEstimado;

  const AccountingSummary({
    required this.ingresosLavados,
    required this.totalGastos,
    required this.sueldoDevengado,
    required this.nominaNetaPagada,
    required this.adelantosEntregados,
    required this.abonosRecibidos,
    required this.utilidadOperativa,
    required this.movimientoNetoEfectivo,
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
      movimientoNetoEfectivo: _asDouble(
        json['movimiento_neto_efectivo'] ?? json['flujo_efectivo_estimado'],
      ),
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
