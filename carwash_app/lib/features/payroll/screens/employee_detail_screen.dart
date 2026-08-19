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
import '../models/advance_model.dart';
import '../models/employee_model.dart';
import '../models/payroll_models.dart';
import '../services/payroll_service.dart';

AdvanceStatus _toAdvanceStatus(String s) => switch (s) {
  'pendiente' => AdvanceStatus.pendiente,
  'parcialmente_pagado' => AdvanceStatus.parcialmentePagado,
  'pagado' => AdvanceStatus.pagado,
  _ => AdvanceStatus.anulado,
};

class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.employee});
  final Employee employee;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  Employee? _full;
  List<EmployeeSalary> _salaryHistory = [];
  List<Advance> _advances = [];
  List<PayrollPayment> _payments = [];
  bool _loadingFull = true;
  bool _loadingAdvances = true;
  bool _loadingPayments = true;
  bool _savingStatus = false;
  String? _errorFull;
  String? _paymentsError;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFull();
      _loadAdvances();
      _loadPayments();
    });
  }

  Future<void> _loadFull() async {
    setState(() {
      _loadingFull = true;
      _errorFull = null;
    });
    try {
      final emp = await PayrollService.getEmployee(widget.employee.id);
      final history = await PayrollService.getSalaryHistory(widget.employee.id);
      if (!mounted) return;
      setState(() {
        _full = emp;
        _salaryHistory = history;
        _loadingFull = false;
      });
    } catch (e) {
      debugPrint('[EmployeeDetailScreen] Error loading detail: $e');
      if (!mounted) return;
      setState(() {
        _errorFull = 'No se pudo cargar el detalle del trabajador.';
        _loadingFull = false;
      });
    }
  }

  Future<void> _loadPayments() async {
    setState(() {
      _loadingPayments = true;
      _paymentsError = null;
    });
    try {
      final list = await PayrollService.getEmployeePayrollPayments(
        widget.employee.id,
      );
      debugPrint('[EmployeeDetailScreen] Payroll payments: ${list.length}');
      if (!mounted) return;
      setState(() {
        _payments = list;
        _loadingPayments = false;
      });
    } catch (e) {
      debugPrint('[EmployeeDetailScreen] Error loading payroll payments: $e');
      if (!mounted) return;
      setState(() {
        _paymentsError =
            'No se pudo cargar los pagos de nómina del trabajador.';
        _loadingPayments = false;
      });
    }
  }

  Future<void> _loadAdvances() async {
    try {
      final list = await PayrollService.getEmployeeAdvances(widget.employee.id);
      debugPrint('[EmployeeDetailScreen] Advances loaded: ${list.length}');
      if (!mounted) return;
      setState(() {
        _advances = list;
        _loadingAdvances = false;
      });
    } catch (e) {
      debugPrint('[EmployeeDetailScreen] Error loading advances: $e');
      if (!mounted) return;
      setState(() {
        _loadingAdvances = false;
      });
    }
  }

  Future<void> _goToRegisterAdvance() async {
    final emp = _full ?? widget.employee;
    final done = await context.push<bool>(
      AppRouter.registerAdvance,
      extra: {'employee': emp},
    );
    if ((done ?? false) && mounted) {
      _didChange = true;
      setState(() {
        _loadingAdvances = true;
      });
      _loadAdvances();
    }
  }

  Future<void> _goToEditAdvance(Advance advance) async {
    final emp = _full ?? widget.employee;
    final done = await context.push<bool>(
      AppRouter.registerAdvance,
      extra: {'employee': emp, 'existingAdvance': advance},
    );
    if ((done ?? false) && mounted) {
      _didChange = true;
      setState(() {
        _loadingAdvances = true;
      });
      _loadAdvances();
    }
  }

  Future<void> _goToEditSalary() async {
    final emp = _full ?? widget.employee;
    final done = await context.push<bool>(
      AppRouter.editSalary,
      extra: emp,
    );
    if ((done ?? false) && mounted) {
      _didChange = true;
      _loadFull();
    }
  }

  Future<void> _changeStatus({required bool active}) async {
    final emp = _display;
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            '¿Desactivar trabajador?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Este trabajador no podrá usarse como activo, pero su historial se conservará.',
            style: GoogleFonts.inter(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _savingStatus = true);
    try {
      final updated = active
          ? await PayrollService.activateEmployee(emp.id)
          : await PayrollService.deactivateEmployee(emp.id);
      if (!mounted) return;
      setState(() {
        _full = updated;
        _savingStatus = false;
        _didChange = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Trabajador reactivado correctamente.'
                : 'Trabajador desactivado correctamente.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.successFg,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadFull();
    } catch (e) {
      debugPrint('[EmployeeDetailScreen] Error changing employee status: $e');
      if (!mounted) return;
      setState(() => _savingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el estado del trabajador.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.errorFg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goBack() => context.pop(_didChange);

  Employee get _display => _full ?? widget.employee;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 12),
                    _buildSalaryCard(),
                    const SizedBox(height: 12),
                    _buildAdvancesSection(),
                    const SizedBox(height: 12),
                    _buildPayrollPaymentsSection(),
                    if (_salaryHistory.length > 1) ...[
                      const SizedBox(height: 12),
                      _buildHistorySection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  _display.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final emp = _display;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    emp.firstName.isNotEmpty
                        ? emp.firstName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge.raw(
                      label: emp.isActive ? 'activo' : 'inactivo',
                      bg: emp.isActive
                          ? AppColors.successBg
                          : AppColors.errorBg,
                      fg: emp.isActive
                          ? AppColors.successFg
                          : AppColors.errorFg,
                      dot: emp.isActive
                          ? AppColors.successDot
                          : AppColors.errorDot,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          if (emp.phone != null)
            _DetailRow(label: 'Teléfono', value: emp.phone!),
          _DetailRow(
            label: 'Fecha contratación',
            value: Fmt.dateFull(emp.hireDate),
          ),
          const SizedBox(height: 10),
          _StatusActionButton(
            active: emp.isActive,
            loading: _savingStatus,
            onPressed: _savingStatus
                ? null
                : () => _changeStatus(active: !emp.isActive),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard() {
    if (_loadingFull && _display.currentSalary == null) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    if (_errorFull != null && _display.currentSalary == null) {
      return AppCard(
        child: Text(
          _errorFull!,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }
    final salary = _display.currentSalary;
    if (salary == null) {
      return AppCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Sin salario registrado',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            IconButton(
              onPressed: _goToEditSalary,
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              tooltip: 'Editar sueldo',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SALARIO ACTUAL',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              IconButton(
                onPressed: _goToEditSalary,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                tooltip: 'Editar sueldo',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Fmt.lempira(salary.salary),
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _DetailRow(label: 'Frecuencia', value: salary.frequencyLabel),
          _DetailRow(
            label: 'Días por periodo',
            value: '${salary.workDaysPerPeriod} días',
          ),
          _DetailRow(
            label: 'Valor diario',
            value: Fmt.lempira(salary.dailyRate),
          ),
          _DetailRow(
            label: 'Vigente desde',
            value: Fmt.dateFull(salary.effectiveFrom),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: 'Adelantos')),
            TextButton.icon(
              onPressed: _goToRegisterAdvance,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'Registrar',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingAdvances)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_advances.isEmpty)
          AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sin adelantos pendientes',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          )
        else
          Column(
            children: _advances
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AdvanceCard(
                      advance: a,
                      onEdit: (a.isPending || a.isPartial)
                          ? () => _goToEditAdvance(a)
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Historial de sueldos'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              for (int i = 0; i < _salaryHistory.length; i++) ...[
                if (i > 0) const Divider(color: AppColors.border, height: 20),
                _SalaryHistoryRow(salary: _salaryHistory[i], isCurrent: i == 0),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPayrollPaymentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Pagos de nómina'),
        const SizedBox(height: 10),
        if (_loadingPayments)
          const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else if (_paymentsError != null)
          AppCard(
            child: Column(
              children: [
                Text(
                  _paymentsError!,
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
                  onPressed: _loadPayments,
                  icon: Icons.refresh_rounded,
                  size: AppButtonSize.sm,
                  fullWidth: false,
                ),
              ],
            ),
          )
        else if (_payments.isEmpty)
          AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No hay pagos de nómina registrados para este trabajador.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          )
        else
          Column(
            children: _payments
                .map(
                  (payment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PayrollPaymentCard(payment: payment),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

// ─── Detail row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.active,
    required this.loading,
    required this.onPressed,
  });

  final bool active;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.errorFg : AppColors.successFg;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(
                active
                    ? Icons.person_off_rounded
                    : Icons.person_add_alt_1_rounded,
                size: 17,
              ),
        label: Text(active ? 'Desactivar trabajador' : 'Reactivar trabajador'),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(120)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PayrollPaymentCard extends StatelessWidget {
  const _PayrollPaymentCard({required this.payment});

  final PayrollPayment payment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _paymentPeriodLabel(payment),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge.raw(
                label: _payrollStatusLabel(payment.status),
                bg: _payrollStatusBg(payment.status),
                fg: _payrollStatusFg(payment.status),
                dot: _payrollStatusDot(payment.status),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Pagado el ${Fmt.dateFull(payment.paymentDate)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _PaymentChip(
                icon: Icons.today_outlined,
                label: '${payment.daysWorked.toStringAsFixed(2)} días',
              ),
              _PaymentChip(
                icon: Icons.work_history_outlined,
                label: 'Bruto ${Fmt.lempira(payment.grossAmount)}',
              ),
              _PaymentChip(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Adelanto ${Fmt.lempira(payment.advanceDiscount)}',
              ),
              _PaymentChip(
                icon: Icons.payments_outlined,
                label: 'Neto ${Fmt.lempira(payment.netAmount)}',
              ),
            ],
          ),
          if (payment.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              payment.notes!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _paymentPeriodLabel(PayrollPayment payment) {
  final period = payment.period;
  if (period == null) return 'Periodo #${payment.periodId}';
  return 'Semana ${Fmt.dateShort(period.startDate)} - ${Fmt.dateShort(period.endDate)}';
}

String _payrollStatusLabel(String status) => switch (status) {
  'pagado' => 'pagado',
  'borrador' => 'borrador',
  'anulado' => 'anulado',
  _ => status,
};

Color _payrollStatusBg(String status) => switch (status) {
  'pagado' => AppColors.successBg,
  'borrador' => AppColors.warningBg,
  'anulado' => AppColors.errorBg,
  _ => AppColors.infoBg,
};

Color _payrollStatusFg(String status) => switch (status) {
  'pagado' => AppColors.successFg,
  'borrador' => AppColors.warningFg,
  'anulado' => AppColors.errorFg,
  _ => AppColors.infoFg,
};

Color _payrollStatusDot(String status) => switch (status) {
  'pagado' => AppColors.successDot,
  'borrador' => AppColors.warningDot,
  'anulado' => AppColors.errorDot,
  _ => AppColors.infoDot,
};

// ─── Advance card ─────────────────────────────────────────────────────────────

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.advance, this.onEdit});
  final Advance advance;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.lempira(advance.amount),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusBadge.advance(_toAdvanceStatus(advance.status)),
              if (onEdit != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  tooltip: 'Editar adelanto',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Saldo: ${Fmt.lempira(advance.balance)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Fmt.dateFull(advance.advanceDate),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (advance.amount > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: advance.progress,
                minHeight: 4,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.accent,
                ),
              ),
            ),
          ],
          if (advance.notes != null) ...[
            const SizedBox(height: 6),
            Text(
              advance.notes!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Salary history row ───────────────────────────────────────────────────────

class _SalaryHistoryRow extends StatelessWidget {
  const _SalaryHistoryRow({required this.salary, required this.isCurrent});
  final EmployeeSalary salary;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Fmt.lempira(salary.salary),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
              Text(
                '${salary.frequencyLabel} · ${Fmt.lempira(salary.dailyRate)}/día',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Vigente',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.infoFg,
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              'Desde ${Fmt.dateShort(salary.effectiveFrom)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
