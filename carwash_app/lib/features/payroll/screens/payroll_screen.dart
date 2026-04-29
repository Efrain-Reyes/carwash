import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/summary_card.dart';
import '../models/advance_model.dart';
import '../models/employee_model.dart';
import '../services/payroll_service.dart';

AdvanceStatus _toAdvanceStatus(String s) => switch (s) {
  'pendiente' => AdvanceStatus.pendiente,
  'parcialmente_pagado' => AdvanceStatus.parcialmentePagado,
  'pagado' => AdvanceStatus.pagado,
  _ => AdvanceStatus.anulado,
};

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Employee> _employees = [];
  List<Advance> _pendingAdvances = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    debugPrint('[PayrollScreen] _load() started');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final emps = await PayrollService.getEmployees();
      debugPrint('[PayrollScreen] employees loaded: ${emps.length}');

      final allAdvances = await PayrollService.getAdvances();
      debugPrint('[PayrollScreen] advances loaded: ${allAdvances.length}');
      final pending = allAdvances
          .where((a) => a.isPending || a.isPartial)
          .toList();

      if (!mounted) return;
      setState(() {
        _employees = emps;
        _pendingAdvances = pending;
        _loading = false;
      });
      debugPrint(
        '[PayrollScreen] summary refreshed — '
        '${emps.length} empleados, ${pending.length} adelantos pendientes',
      );
    } catch (e) {
      debugPrint('[PayrollScreen] error: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cargar la información.\nVerifica tu red e intenta de nuevo.';
        _loading = false;
      });
    }
  }

  int get _activeCount => _employees.where((e) => e.isActive).length;
  double get _pendingTotal =>
      _pendingAdvances.fold(0.0, (s, a) => s + a.balance);

  // Abre una ruta y siempre refresca al volver
  Future<void> _pushAndRefresh(String route, {Object? extra}) async {
    await context.push(route, extra: extra);
    if (mounted) {
      debugPrint('[PayrollScreen] returned from $route — refreshing...');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Text(
            'Nómina',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_error != null) {
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
                _error!,
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
                onPressed: _load,
                icon: Icons.refresh_rounded,
                fullWidth: false,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjetas de resumen
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    compact: true,
                    label: 'Activos',
                    value: '$_activeCount',
                    icon: Icons.group_rounded,
                    iconColor: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    compact: true,
                    label: 'Adelantos',
                    value: '${_pendingAdvances.length}',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.warningDot,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    compact: true,
                    label: 'Saldo pendiente',
                    value: Fmt.lempira(_pendingTotal),
                    icon: Icons.money_off_rounded,
                    iconColor: AppColors.errorFg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    compact: true,
                    label: 'Total empleados',
                    value: '${_employees.length}',
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            SectionHeader(title: 'Accesos'),
            const SizedBox(height: 10),
            _QuickBtn(
              icon: Icons.group_outlined,
              label: 'Trabajadores',
              subtitle: '$_activeCount activos · ${_employees.length} total',
              onTap: () => _pushAndRefresh(AppRouter.employees),
            ),
            const SizedBox(height: 8),
            _QuickBtn(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Adelantos',
              subtitle:
                  '${_pendingAdvances.length} pendientes · '
                  '${Fmt.lempira(_pendingTotal)}',
              onTap: () => _pushAndRefresh(AppRouter.advances),
            ),
            const SizedBox(height: 8),
            _QuickBtn(
              icon: Icons.payments_outlined,
              label: 'Pagar nómina',
              subtitle: 'Calcular sueldo y descontar adelantos',
              onTap: () => _pushAndRefresh(AppRouter.payrollPay),
            ),
            const SizedBox(height: 8),
            _QuickBtn(
              icon: Icons.add_circle_outline_rounded,
              label: 'Registrar adelanto',
              subtitle: 'Nuevo adelanto a un trabajador',
              onTap: () => _pushAndRefresh(AppRouter.registerAdvance),
            ),

            if (_pendingAdvances.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionHeader(title: 'Adelantos pendientes'),
              const SizedBox(height: 10),
              ..._pendingAdvances
                  .take(3)
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AdvanceMiniCard(
                        advance: a,
                        onTap: () async {
                          final result = await context.push<bool>(
                            AppRouter.advanceDetail(a.id),
                            extra: a,
                          );
                          if ((result ?? false) && mounted) await _load();
                        },
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Quick access button ──────────────────────────────────────────────────────

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: AppColors.textMuted2,
          ),
        ],
      ),
    );
  }
}

// ─── Advance mini card ────────────────────────────────────────────────────────

class _AdvanceMiniCard extends StatelessWidget {
  const _AdvanceMiniCard({required this.advance, required this.onTap});
  final Advance advance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advance.employeeName.isNotEmpty
                      ? advance.employeeName
                      : 'Empleado #${advance.employeeId}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pendiente: ${Fmt.lempira(advance.balance)} '
                  'de ${Fmt.lempira(advance.amount)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge.advance(_toAdvanceStatus(advance.status)),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: AppColors.textMuted2,
          ),
        ],
      ),
    );
  }
}
