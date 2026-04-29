double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class ReportTimelineModel {
  final ReportTimelinePeriod periodo;
  final List<ReportTimelinePoint> timeline;

  const ReportTimelineModel({required this.periodo, required this.timeline});

  factory ReportTimelineModel.fromJson(Map<String, dynamic> json) {
    final timeline = json['timeline'] as List? ?? [];
    final periodo = json['periodo'];
    return ReportTimelineModel(
      periodo: ReportTimelinePeriod.fromJson(
        periodo is Map<String, dynamic> ? periodo : const {},
      ),
      timeline: timeline
          .map((e) => ReportTimelinePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReportTimelinePeriod {
  final DateTime? desde;
  final DateTime? hasta;

  const ReportTimelinePeriod({this.desde, this.hasta});

  factory ReportTimelinePeriod.fromJson(Map<String, dynamic> json) {
    return ReportTimelinePeriod(
      desde: _asDate(json['desde'] ?? json['date_from']),
      hasta: _asDate(json['hasta'] ?? json['date_to']),
    );
  }
}

class ReportTimelinePoint {
  final DateTime fecha;
  final double ingresosLavados;
  final double gastos;
  final double utilidadOperativa;
  final double flujoEfectivoEstimado;

  const ReportTimelinePoint({
    required this.fecha,
    required this.ingresosLavados,
    required this.gastos,
    required this.utilidadOperativa,
    required this.flujoEfectivoEstimado,
  });

  factory ReportTimelinePoint.fromJson(Map<String, dynamic> json) {
    return ReportTimelinePoint(
      fecha: _asDate(json['fecha']) ?? DateTime.now(),
      ingresosLavados: _asDouble(json['ingresos_lavados']),
      gastos: _asDouble(json['gastos']),
      utilidadOperativa: _asDouble(json['utilidad_operativa']),
      flujoEfectivoEstimado: _asDouble(json['flujo_efectivo_estimado']),
    );
  }
}
