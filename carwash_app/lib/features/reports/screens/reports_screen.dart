import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/report_timeline_model.dart';
import '../models/accounting_report.dart';
import '../services/reports_service.dart';

enum _ReportRange { today, week, month, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  AccountingReport? _report;
  ReportTimelineModel? _timeline;
  _ReportRange _range = _ReportRange.today;
  late DateTime _dateFrom;
  late DateTime _dateTo;
  bool _loading = true;
  bool _timelineLoading = false;
  String? _error;
  String? _timelineError;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dateFrom = today;
    _dateTo = today;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _timelineLoading = true;
      _timelineError = null;
      _timeline = null;
    });

    final dateFrom = Fmt.dateApi(_dateFrom);
    final dateTo = Fmt.dateApi(_dateTo);

    try {
      await _ensureCurrentCashSession();

      final report = await ReportsService.getAccounting(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint('[ReportsScreen] DioException: ${e.response?.statusCode}');
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cargar el reporte.\nVerifica tu red e intenta de nuevo.';
        _loading = false;
        _timelineLoading = false;
      });
      return;
    } catch (e) {
      debugPrint('[ReportsScreen] Unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Error inesperado al cargar el reporte.';
        _loading = false;
        _timelineLoading = false;
      });
      return;
    }

    await _loadTimeline(showLoading: false);
  }

  Future<void> _ensureCurrentCashSession() async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final fromOnly = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
    final toOnly = DateTime(_dateTo.year, _dateTo.month, _dateTo.day);

    if (todayOnly.isBefore(fromOnly) || todayOnly.isAfter(toOnly)) return;

    try {
      await ReportsService.getCurrentCashSession();
    } on DioException catch (e) {
      debugPrint(
        '[ReportsScreen] Current cash DioException: ${e.response?.statusCode}',
      );
    } catch (e) {
      debugPrint('[ReportsScreen] Current cash unexpected error: $e');
    }
  }

  Future<void> _loadTimeline({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _timelineLoading = true;
        _timelineError = null;
      });
    }

    try {
      final timeline = await ReportsService.getAccountingTimeline(
        dateFrom: Fmt.dateApi(_dateFrom),
        dateTo: Fmt.dateApi(_dateTo),
      );
      if (!mounted) return;
      setState(() {
        _timeline = timeline;
        _timelineLoading = false;
        _timelineError = null;
      });
    } on DioException catch (e) {
      debugPrint(
        '[ReportsScreen] Timeline DioException: ${e.response?.statusCode}',
      );
      if (!mounted) return;
      setState(() {
        _timelineError = 'No se pudo cargar la tendencia.';
        _timelineLoading = false;
      });
    } catch (e) {
      debugPrint('[ReportsScreen] Timeline unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _timelineError = 'No se pudo cargar la tendencia.';
        _timelineLoading = false;
      });
    }
  }

  void _setRange(_ReportRange range) {
    final today = DateTime.now();
    setState(() {
      _range = range;
      if (range == _ReportRange.today) {
        _dateFrom = today;
        _dateTo = today;
      } else if (range == _ReportRange.week) {
        _dateFrom = today.subtract(Duration(days: today.weekday - 1));
        _dateTo = today;
      } else if (range == _ReportRange.month) {
        _dateFrom = DateTime(today.year, today.month);
        _dateTo = today;
      }
    });
    if (range != _ReportRange.custom) _load();
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _applyCustomRange() async {
    if (_dateTo.isBefore(_dateFrom)) {
      setState(() => _error = 'La fecha Hasta debe ser posterior a Desde.');
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ReportsHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _report == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null && _report == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final report = _report;
    if (report == null) return const SizedBox.shrink();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: AppColors.border,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: _error!, onRetry: _load),
            ],
            const SizedBox(height: 16),
            _ReportPeriodLabel(dateFrom: _dateFrom, dateTo: _dateTo),
            const SizedBox(height: 12),
            if (!report.hasMovements) ...[
              const _EmptyMovementsCard(),
              const SizedBox(height: 14),
            ],
            _SummarySection(report: report),
            const SizedBox(height: 18),
            if (report.caja != null) ...[
              _CashSection(caja: report.caja!),
              const SizedBox(height: 18),
            ],
            _BusinessTrendSection(
              timeline: _timeline,
              loading: _timelineLoading,
              error: _timelineError,
              onRetry: () => _loadTimeline(),
            ),
            const SizedBox(height: 18),
            _WashesSection(lavados: report.lavados),
            const SizedBox(height: 18),
            _ExpensesSection(gastos: report.gastosDetalle),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _RangeChip(
                label: 'Hoy',
                active: _range == _ReportRange.today,
                onTap: () => _setRange(_ReportRange.today),
              ),
              const SizedBox(width: 8),
              _RangeChip(
                label: 'Esta semana',
                active: _range == _ReportRange.week,
                onTap: () => _setRange(_ReportRange.week),
              ),
              const SizedBox(width: 8),
              _RangeChip(
                label: 'Este mes',
                active: _range == _ReportRange.month,
                onTap: () => _setRange(_ReportRange.month),
              ),
              const SizedBox(width: 8),
              _RangeChip(
                label: 'Rango personalizado',
                active: _range == _ReportRange.custom,
                onTap: () => _setRange(_ReportRange.custom),
              ),
            ],
          ),
        ),
        if (_range == _ReportRange.custom) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateBox(
                        label: 'Desde',
                        value: Fmt.dateFull(_dateFrom),
                        onTap: () => _pickDate(
                          initialDate: _dateFrom,
                          onPicked: (d) => _dateFrom = d,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateBox(
                        label: 'Hasta',
                        value: Fmt.dateFull(_dateTo),
                        onTap: () => _pickDate(
                          initialDate: _dateTo,
                          onPicked: (d) => _dateTo = d,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Aplicar',
                  onPressed: _applyCustomRange,
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reportes',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Resumen contable del carwash',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.report});

  final AccountingReport report;

  @override
  Widget build(BuildContext context) {
    final r = report.resumen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Resumen contable'),
        const SizedBox(height: 10),
        _MetricGrid(
          cards: [
            _MetricCardData(
              label: 'Ingresos por lavados',
              value: r.ingresosLavados,
              icon: Icons.local_car_wash_rounded,
              color: AppColors.successFg,
            ),
            _MetricCardData(
              label: 'Total de gastos',
              value: r.totalGastos,
              icon: Icons.receipt_long_rounded,
              color: AppColors.errorFg,
            ),
            _MetricCardData(
              label: 'Sueldo devengado',
              value: r.sueldoDevengado,
              icon: Icons.work_history_rounded,
              color: AppColors.primary,
            ),
            _MetricCardData(
              label: 'Nómina neta pagada',
              value: r.nominaNetaPagada,
              icon: Icons.payments_rounded,
              color: AppColors.primary,
            ),
            _MetricCardData(
              label: 'Adelantos entregados',
              value: r.adelantosEntregados,
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.warningFg,
            ),
            _MetricCardData(
              label: 'Abonos recibidos',
              value: r.abonosRecibidos,
              icon: Icons.savings_rounded,
              color: AppColors.successFg,
            ),
            _MetricCardData(
              label: 'Utilidad operativa',
              value: r.utilidadOperativa,
              icon: r.utilidadOperativa >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: r.utilidadOperativa >= 0
                  ? AppColors.successFg
                  : AppColors.errorFg,
            ),
            _MetricCardData(
              label: 'Movimiento neto de efectivo',
              value: r.movimientoNetoEfectivo,
              icon: r.movimientoNetoEfectivo >= 0
                  ? Icons.show_chart_rounded
                  : Icons.stacked_line_chart_rounded,
              color: r.movimientoNetoEfectivo >= 0
                  ? AppColors.successFg
                  : AppColors.errorFg,
            ),
          ],
        ),
      ],
    );
  }
}

class _CashSection extends StatelessWidget {
  const _CashSection({required this.caja});

  final AccountingCash caja;

  @override
  Widget build(BuildContext context) {
    final difference = caja.diferenciaCaja;
    final differenceColor = difference == null || difference == 0
        ? AppColors.successFg
        : AppColors.errorFg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Caja'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              _CashRow(
                label: 'Saldo inicial',
                value: Fmt.lempira(caja.saldoInicialCaja),
              ),
              _CashRow(
                label: 'Movimiento neto',
                value: Fmt.lempira(caja.movimientoNetoEfectivo),
              ),
              _CashRow(
                label: 'Dinero esperado en caja',
                value: Fmt.lempira(caja.saldoFinalEstimado),
              ),
              if (caja.efectivoContado != null)
                _CashRow(
                  label: 'Efectivo total contado en caja',
                  value: Fmt.lempira(caja.efectivoContado!),
                ),
              if (difference != null)
                _CashRow(
                  label: 'Diferencia de caja',
                  value: Fmt.lempira(difference),
                  valueColor: differenceColor,
                  showDivider: false,
                )
              else
                _CashRow(
                  label: 'Estado',
                  value: caja.isClosed ? 'Cerrada' : 'Abierta',
                  showDivider: false,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CashRow extends StatelessWidget {
  const _CashRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.border),
          ),
      ],
    );
  }
}

class _BusinessTrendSection extends StatelessWidget {
  const _BusinessTrendSection({
    required this.timeline,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final ReportTimelineModel? timeline;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final points = timeline?.timeline ?? const <ReportTimelinePoint>[];
    final hasValues = points.any(
      (point) =>
          point.ingresosLavados != 0 ||
          point.gastos != 0 ||
          point.utilidadOperativa != 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Tendencia del negocio'),
        const SizedBox(height: 10),
        if (loading)
          const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          )
        else if (error != null)
          _TrendErrorCard(message: error!, onRetry: onRetry)
        else if (points.isEmpty || !hasValues)
          const _EmptySectionCard(
            message: 'No hay datos suficientes para graficar este periodo.',
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresos, gastos y utilidad del periodo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const _TrendLegend(),
                const SizedBox(height: 18),
                SizedBox(height: 250, child: _TrendLineChart(points: points)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(label: 'Ingresos', color: AppColors.primary),
        _LegendItem(label: 'Gastos', color: AppColors.errorFg),
        _LegendItem(label: 'Utilidad', color: AppColors.successFg),
      ],
    );
  }
}

class _TrendErrorCard extends StatelessWidget {
  const _TrendErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.errorFg,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Reintentar',
            onPressed: onRetry,
            icon: Icons.refresh_rounded,
            size: AppButtonSize.sm,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({required this.points});

  final List<ReportTimelinePoint> points;

  @override
  Widget build(BuildContext context) {
    final sorted = [...points]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final values = <double>[
      for (final point in sorted) ...[
        point.ingresosLavados,
        point.gastos,
        point.utilidadOperativa,
      ],
      0,
    ];

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;
    final padding = range == 0
        ? math.max(maxValue.abs() * 0.2, 100)
        : range * 0.14;
    final minY = minValue - padding;
    final maxY = maxValue + padding;
    final yInterval = _niceInterval(maxY - minY);
    final maxX = math.max(sorted.length - 1, 1).toDouble();
    final bottomInterval = sorted.length <= 7
        ? 1.0
        : math.max(((sorted.length - 1) / 3).ceil(), 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(border: Border.all(color: AppColors.border)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 54,
              interval: yInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  _compactLempira(value),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: bottomInterval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 0.01 ||
                    index < 0 ||
                    index >= sorted.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    _axisDate(sorted[index].fecha),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            maxContentWidth: 180,
            tooltipBorderRadius: BorderRadius.circular(12),
            getTooltipColor: (_) => AppColors.primary,
            getTooltipItems: (spots) => spots.map((spot) {
              final label = switch (spot.barIndex) {
                0 => 'Ingresos',
                1 => 'Gastos',
                _ => 'Utilidad',
              };
              return LineTooltipItem(
                '$label\n${Fmt.lempira(spot.y)}',
                GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          _chartLine(
            sorted,
            (point) => point.ingresosLavados,
            AppColors.primary,
          ),
          _chartLine(sorted, (point) => point.gastos, AppColors.errorFg),
          _chartLine(
            sorted,
            (point) => point.utilidadOperativa,
            AppColors.successFg,
          ),
        ],
      ),
    );
  }

  LineChartBarData _chartLine(
    List<ReportTimelinePoint> source,
    double Function(ReportTimelinePoint point) valueOf,
    Color color,
  ) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < source.length; i++)
          FlSpot(i.toDouble(), valueOf(source[i])),
      ],
      color: color,
      barWidth: 3,
      isCurved: source.length > 2,
      curveSmoothness: 0.22,
      preventCurveOverShooting: true,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(show: source.length <= 10),
      belowBarData: BarAreaData(show: true, color: color.withAlpha(16)),
    );
  }
}

double _niceInterval(double range) {
  if (range <= 0) return 1;
  final rough = range / 4;
  final exponent = math.pow(10, (math.log(rough) / math.ln10).floor());
  final fraction = rough / exponent;
  final niceFraction = fraction <= 1
      ? 1
      : fraction <= 2
      ? 2
      : fraction <= 5
      ? 5
      : 10;
  return (niceFraction * exponent).toDouble();
}

String _compactLempira(double amount) {
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  if (abs >= 1000000) {
    final value = abs / 1000000;
    return '${sign}L ${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
  }
  if (abs >= 1000) {
    final value = abs / 1000;
    return '${sign}L ${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
  }
  return '${sign}L ${abs.toStringAsFixed(0)}';
}

String _axisDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class _WashesSection extends StatelessWidget {
  const _WashesSection({required this.lavados});

  final AccountingWashes lavados;

  @override
  Widget build(BuildContext context) {
    final hasData =
        lavados.cantidad > 0 ||
        lavados.porVehiculo.isNotEmpty ||
        lavados.porServicio.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Lavados'),
        const SizedBox(height: 10),
        if (!hasData)
          const _EmptySectionCard(message: 'No hay lavados en este periodo.')
        else ...[
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_car_wash_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${lavados.cantidad} lavados registrados',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _VehicleDistributionCard(items: lavados.porVehiculo),
          const SizedBox(height: 10),
          _TopServicesCard(items: lavados.porServicio),
        ],
      ],
    );
  }
}

class _VehicleDistributionCard extends StatelessWidget {
  const _VehicleDistributionCard({required this.items});

  final List<WashesByVehicle> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.total.compareTo(a.total));
    final totalAmount = sorted.fold<double>(0, (sum, item) => sum + item.total);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Por tipo de vehículo',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty || totalAmount <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No hay lavados por vehículo en este periodo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final chart = SizedBox(
                  width: 174,
                  height: 174,
                  child: _VehicleDonutChart(
                    items: sorted,
                    totalAmount: totalAmount,
                  ),
                );
                final legend = _VehicleLegend(
                  items: sorted,
                  totalAmount: totalAmount,
                );

                if (constraints.maxWidth >= 520) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      chart,
                      const SizedBox(width: 18),
                      Expanded(child: legend),
                    ],
                  );
                }

                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 16),
                    legend,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _VehicleDonutChart extends StatelessWidget {
  const _VehicleDonutChart({required this.items, required this.totalAmount});

  final List<WashesByVehicle> items;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        startDegreeOffset: -90,
        sectionsSpace: items.length == 1 ? 0 : 3,
        centerSpaceRadius: 48,
        centerSpaceColor: AppColors.surface,
        pieTouchData: PieTouchData(enabled: false),
        sections: [
          for (var i = 0; i < items.length; i++)
            PieChartSectionData(
              value: items[i].total,
              color: _vehicleColor(i),
              radius: 38,
              cornerRadius: 6,
              showTitle: _vehiclePercent(items[i].total, totalAmount) >= 8,
              title:
                  '${_vehiclePercent(items[i].total, totalAmount).toStringAsFixed(0)}%',
              titleStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleLegend extends StatelessWidget {
  const _VehicleLegend({required this.items, required this.totalAmount});

  final List<WashesByVehicle> items;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _VehicleLegendRow(
            item: items[i],
            color: _vehicleColor(i),
            percent: _vehiclePercent(items[i].total, totalAmount),
          ),
          if (i + 1 < items.length)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.border),
            ),
        ],
      ],
    );
  }
}

class _VehicleLegendRow extends StatelessWidget {
  const _VehicleLegendRow({
    required this.item,
    required this.color,
    required this.percent,
  });

  final WashesByVehicle item;
  final Color color;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 11,
          height: 11,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.tipo,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '${_lavadosLabel(item.cantidad)} · ${Fmt.lempira(item.total)} · ${percent.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _vehicleColor(int index) {
  const colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.successFg,
    AppColors.warningDot,
    AppColors.infoFg,
    AppColors.errorFg,
  ];
  return colors[index % colors.length];
}

double _vehiclePercent(double amount, double total) =>
    total <= 0 ? 0 : amount / total * 100;

String _lavadosLabel(int count) => count == 1 ? '1 lavado' : '$count lavados';

class _TopServicesCard extends StatelessWidget {
  const _TopServicesCard({required this.items});

  final List<WashesByService> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.total.compareTo(a.total));
    final totalAmount = sorted.fold<double>(0, (sum, item) => sum + item.total);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Servicios más vendidos',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty || totalAmount <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No hay servicios registrados en este periodo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  _TopServiceRow(
                    item: sorted[i],
                    percent: sorted[i].total / totalAmount,
                    color: _serviceColor(i),
                  ),
                  if (i + 1 < sorted.length) const SizedBox(height: 14),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TopServiceRow extends StatelessWidget {
  const _TopServiceRow({
    required this.item,
    required this.percent,
    required this.color,
  });

  final WashesByService item;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safePercent = percent.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(safePercent * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${_servicesLabel(item.cantidad)} · ${Fmt.lempira(item.total)}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safePercent,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

Color _serviceColor(int index) {
  const colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.infoFg,
    AppColors.successFg,
    AppColors.warningDot,
  ];
  return colors[index % colors.length];
}

String _servicesLabel(int count) =>
    count == 1 ? '1 servicio' : '$count servicios';

class _ExpensesSection extends StatelessWidget {
  const _ExpensesSection({required this.gastos});

  final AccountingExpensesDetail gastos;

  @override
  Widget build(BuildContext context) {
    final hasData = gastos.porProveedor.isNotEmpty || gastos.porItem.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Gastos'),
        const SizedBox(height: 10),
        if (!hasData)
          const _EmptySectionCard(message: 'No hay gastos en este periodo.')
        else ...[
          _SupplierExpensesCard(items: gastos.porProveedor),
          if (gastos.porItem.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RankingList(
              title: 'Ranking por ítem',
              items: gastos.porItem
                  .map(
                    (item) => _RankingItemData(
                      label: item.descripcion,
                      detail: 'Cant. ${item.cantidad.toStringAsFixed(2)}',
                      amount: item.total,
                    ),
                  )
                  .toList(),
              total: gastos.porItem.fold<double>(
                0,
                (sum, item) => sum + item.total,
              ),
              accentColor: AppColors.warningFg,
            ),
          ],
        ],
      ],
    );
  }
}

class _SupplierExpensesCard extends StatelessWidget {
  const _SupplierExpensesCard({required this.items});

  final List<ExpensesBySupplier> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.total.compareTo(a.total));
    final totalAmount = sorted.fold<double>(0, (sum, item) => sum + item.total);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastos por proveedor',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty || totalAmount <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No hay gastos por proveedor en este periodo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  _SupplierExpenseRow(
                    item: sorted[i],
                    percent: sorted[i].total / totalAmount,
                    color: _supplierExpenseColor(i),
                  ),
                  if (i + 1 < sorted.length) const SizedBox(height: 14),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SupplierExpenseRow extends StatelessWidget {
  const _SupplierExpenseRow({
    required this.item,
    required this.percent,
    required this.color,
  });

  final ExpensesBySupplier item;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safePercent = percent.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.proveedor,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(safePercent * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${_facturasLabel(item.facturas)} · ${Fmt.lempira(item.total)}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safePercent,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

Color _supplierExpenseColor(int index) {
  const colors = [
    AppColors.errorFg,
    AppColors.warningFg,
    AppColors.errorDot,
    AppColors.warningDot,
    AppColors.primary,
  ];
  return colors[index % colors.length];
}

String _facturasLabel(int count) =>
    count == 1 ? '1 factura' : '$count facturas';

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<_MetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _MetricCard(data: cards[i])),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < cards.length
                  ? _MetricCard(data: cards[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < cards.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: data.color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, size: 15, color: data.color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Fmt.lempira(data.value),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: data.color,
              letterSpacing: -0.4,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.title,
    required this.items,
    required this.total,
    required this.accentColor,
  });

  final String title;
  final List<_RankingItemData> items;
  final double total;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.amount.compareTo(a.amount));
    final effectiveTotal = total > 0
        ? total
        : sorted.fold<double>(0, (sum, item) => sum + item.amount);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sorted.length; i++) ...[
            _RankingRow(
              rank: i + 1,
              item: sorted[i],
              total: effectiveTotal,
              accentColor: accentColor,
            ),
            if (i + 1 < sorted.length)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _RankingItemData {
  const _RankingItemData({
    required this.label,
    required this.detail,
    required this.amount,
  });

  final String label;
  final String detail;
  final double amount;
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.item,
    required this.total,
    required this.accentColor,
  });

  final int rank;
  final _RankingItemData item;
  final double total;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0 : (item.amount / total * 100);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$rank',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.detail,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Fmt.lempira(item.amount),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPeriodLabel extends StatelessWidget {
  const _ReportPeriodLabel({required this.dateFrom, required this.dateTo});

  final DateTime dateFrom;
  final DateTime dateTo;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${Fmt.dateShort(dateFrom)} al ${Fmt.dateShort(dateTo)}',
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _EmptyMovementsCard extends StatelessWidget {
  const _EmptyMovementsCard();

  @override
  Widget build(BuildContext context) {
    return const _EmptySectionCard(
      message: 'No hay movimientos contables en este periodo.',
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.errorFg,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Reintentar',
            onPressed: onRetry,
            icon: Icons.refresh_rounded,
            size: AppButtonSize.sm,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: AppColors.textMuted2,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Reintentar',
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
