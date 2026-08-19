import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cash/screens/cash_sessions_screen.dart';
import '../../expenses/models/expense_model.dart';
import '../../expenses/screens/expenses_screen.dart';
import '../../payroll/screens/payroll_screen.dart';
import '../../reports/models/accounting_report.dart';
import '../../reports/screens/reports_screen.dart';
import '../../washes/models/wash_item.dart';
import '../../washes/screens/washes_screen.dart';
import '../providers/home_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NavTab _currentTab = NavTab.home;

  void _onTabTap(NavTab tab) => setState(() => _currentTab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentTab.index,
        children: [
          _HomeTabBody(onTabChange: _onTabTap),
          const WashesScreen(),
          const ExpensesScreen(),
          const PayrollScreen(),
          const CashSessionsScreen(),
          const ReportsScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(current: _currentTab, onTap: _onTabTap),
    );
  }
}

// ─── Home tab body ────────────────────────────────────────────────────────────

class _HomeTabBody extends StatefulWidget {
  const _HomeTabBody({required this.onTabChange});
  final ValueChanged<NavTab> onTabChange;

  @override
  State<_HomeTabBody> createState() => _HomeTabBodyState();
}

class _HomeTabBodyState extends State<_HomeTabBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<HomeProvider>().loadToday(),
    );
  }

  Future<void> _goToRegisterWash() async {
    final refreshed = await context.push<bool>(AppRouter.registerWash);
    debugPrint('[HomeScreen] push<bool> returned: $refreshed');
    if ((refreshed ?? false) && mounted) {
      debugPrint('[HomeScreen] calling reload()');
      context.read<HomeProvider>().reload();
    }
  }

  Future<void> _refreshHome() async {
    final homeProvider = context.read<HomeProvider>();
    final wasShowingError = homeProvider.error != null;

    if (wasShowingError) {
      await homeProvider.loadToday();
    } else {
      await homeProvider.reload();
    }

    if (!mounted) return;
    final error = homeProvider.error ?? homeProvider.cashError;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  double? _parseAmount(String value) {
    final amount = double.tryParse(value.trim().replaceAll(',', '.'));
    if (amount == null || amount < 0) return null;
    return amount;
  }

  Future<void> _showCreateFirstCashDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final homeProvider = context.read<HomeProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final amount = _parseAmount(amountController.text);
              if (amount == null) {
                setDialogState(
                  () => error = 'Ingresa un efectivo inicial válido.',
                );
                return;
              }

              setDialogState(() {
                submitting = true;
                error = null;
              });

              final ok = await homeProvider.createFirstCashSession(
                openingAmount: amount,
                notes: notesController.text,
              );

              if (!mounted) return;

              if (ok) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Primera caja creada.')),
                );
                return;
              }

              setDialogState(() {
                submitting = false;
                error = homeProvider.cashError;
              });
            }

            return AlertDialog(
              title: const Text('Crear primera caja'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'Efectivo inicial',
                    hint: '0.00',
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Notas',
                    hint: 'Opcional',
                    controller: notesController,
                    maxLines: 3,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.errorFg,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                AppButton(
                  label: 'Crear',
                  onPressed: submitting ? null : submit,
                  fullWidth: false,
                  size: AppButtonSize.sm,
                  loading: submitting,
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    notesController.dispose();
  }

  Future<void> _showCloseCashDialog(AccountingCash cash) async {
    final countedController = TextEditingController();
    final notesController = TextEditingController();
    final homeProvider = context.read<HomeProvider>();
    final report = homeProvider.report;
    final pendingSummary = homeProvider.pendingSummary;
    final washes = homeProvider.recentWashes
        .where((wash) => wash.isCompleted)
        .toList();
    final expenses = homeProvider.todayExpenses
        .where((expense) => expense.isActive)
        .toList();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    var submitting = false;
    var countedText = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final counted = _parseAmount(countedText);
            final difference = counted == null
                ? null
                : counted - cash.saldoFinalEstimado;

            Future<void> submit() async {
              final counted = _parseAmount(countedController.text);
              if (counted == null) {
                setDialogState(
                  () => error =
                      'Ingresa un efectivo total contado en caja válido.',
                );
                return;
              }

              setDialogState(() {
                submitting = true;
                error = null;
              });

              final ok = await homeProvider.closeCashSession(
                id: cash.id,
                countedClosingAmount: counted,
                notes: notesController.text,
              );

              if (!mounted) return;

              if (ok) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Caja cerrada.')),
                );
                return;
              }

              setDialogState(() {
                submitting = false;
                error = homeProvider.cashError;
              });
            }

            return AlertDialog(
              title: const Text('Cerrar caja'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CloseCashSummary(report: report, cash: cash),
                    if (pendingSummary != null &&
                        pendingSummary.diasAbiertos > 1) ...[
                      const SizedBox(height: 12),
                      _PendingDaysBanner(summary: pendingSummary),
                    ],
                    const SizedBox(height: 12),
                    _CloseCashHelpText(),
                    const SizedBox(height: 12),
                    if (difference != null) ...[
                      _DifferenceBox(difference: difference),
                      const SizedBox(height: 12),
                    ],
                    AppTextField(
                      label: 'Efectivo total contado en caja',
                      hint: 'Ej. 1500.00',
                      controller: countedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => countedText = value),
                    ),
                    const SizedBox(height: 6),
                    _CloseCashInputHelp(),
                    const SizedBox(height: 14),
                    _DayWashesList(washes: washes),
                    const SizedBox(height: 12),
                    _DayExpensesList(expenses: expenses),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Notas',
                      hint: 'Opcional',
                      controller: notesController,
                      maxLines: 3,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.errorFg,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                AppButton(
                  label: 'Cerrar',
                  onPressed: submitting ? null : submit,
                  fullWidth: false,
                  size: AppButtonSize.sm,
                  loading: submitting,
                ),
              ],
            );
          },
        );
      },
    );

    countedController.dispose();
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final auth = context.watch<AuthProvider>();

    return Column(
      children: [
        _Header(user: auth.user?.name ?? '', report: home.report),
        Expanded(child: _buildBody(context, home, auth)),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeProvider home,
    AuthProvider auth,
  ) {
    if (home.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (home.error != null) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _refreshHome,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _ErrorView(
                  message: home.error!,
                  onRetry: home.loadToday,
                ),
              ),
            );
          },
        ),
      );
    }
    return _Content(
      report: home.report,
      cashState: home.cashState,
      cashError: home.cashError,
      cashActionLoading: home.cashActionLoading,
      isAdmin: auth.user?.isAdmin ?? false,
      recentWashes: home.recentWashes,
      onRefresh: _refreshHome,
      onTabChange: widget.onTabChange,
      onRegisterWash: _goToRegisterWash,
      onCreateFirstCash: _showCreateFirstCashDialog,
      onCloseCash: _showCloseCashDialog,
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.report});

  final String user;
  final AccountingReport? report;

  @override
  Widget build(BuildContext context) {
    final income = report?.resumen.ingresosLavados ?? 0;

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, $user',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        Fmt.dateSpanish(DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'INGRESOS DE HOY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Fmt.lempira(income),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  const _Content({
    required this.report,
    required this.cashState,
    required this.cashError,
    required this.cashActionLoading,
    required this.isAdmin,
    required this.recentWashes,
    required this.onRefresh,
    required this.onTabChange,
    required this.onRegisterWash,
    required this.onCreateFirstCash,
    required this.onCloseCash,
  });

  final AccountingReport? report;
  final CurrentCashSessionResponse? cashState;
  final String? cashError;
  final bool cashActionLoading;
  final bool isAdmin;
  final List<WashItem> recentWashes;
  final RefreshCallback onRefresh;
  final ValueChanged<NavTab> onTabChange;
  final VoidCallback onRegisterWash;
  final VoidCallback onCreateFirstCash;
  final ValueChanged<AccountingCash> onCloseCash;

  @override
  Widget build(BuildContext context) {
    final r = report?.resumen;
    final washCount = report?.lavados.cantidad ?? 0;
    final movimiento = r?.movimientoNetoEfectivo ?? 0;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards 2×2
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    compact: true,
                    label: 'Ingresos',
                    value: Fmt.lempira(r?.ingresosLavados ?? 0),
                    icon: Icons.local_car_wash_rounded,
                    iconColor: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    compact: true,
                    label: 'Lavados',
                    value: '$washCount',
                    icon: Icons.car_repair_rounded,
                    iconColor: AppColors.primary,
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
                    label: 'Gastos',
                    value: Fmt.lempira(r?.totalGastos ?? 0),
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.warningDot,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    compact: true,
                    label: 'Mov. neto efectivo',
                    value: Fmt.lempira(movimiento),
                    icon: movimiento >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    iconColor: movimiento >= 0
                        ? AppColors.successFg
                        : AppColors.errorFg,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _CashDayCard(
              state: cashState,
              error: cashError,
              isAdmin: isAdmin,
              actionLoading: cashActionLoading,
              onCreateFirstCash: onCreateFirstCash,
              onCloseCash: onCloseCash,
            ),

            const SizedBox(height: 16),

            // Register wash CTA
            _RegisterWashBtn(onTap: onRegisterWash),

            const SizedBox(height: 16),

            // Quick access 2×2
            SectionHeader(title: 'Accesos rápidos'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    icon: Icons.local_car_wash_rounded,
                    label: 'Lavados',
                    onTap: () => onTabChange(NavTab.lavados),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.receipt_long_rounded,
                    label: 'Gastos',
                    onTap: () => onTabChange(NavTab.gastos),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.group_rounded,
                    label: 'Nómina',
                    onTap: () => onTabChange(NavTab.nomina),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reportes',
                    onTap: () => onTabChange(NavTab.reportes),
                  ),
                ),
              ],
            ),

            if (isAdmin) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.category_rounded,
                      label: 'Catálogo',
                      onTap: () => context.push(AppRouter.catalog),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Recent washes
            SectionHeader(title: 'Últimos lavados'),
            const SizedBox(height: 10),
            _RecentWashes(washes: recentWashes),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Cash day card ───────────────────────────────────────────────────────────

class _CashDayCard extends StatelessWidget {
  const _CashDayCard({
    required this.state,
    required this.error,
    required this.isAdmin,
    required this.actionLoading,
    required this.onCreateFirstCash,
    required this.onCloseCash,
  });

  final CurrentCashSessionResponse? state;
  final String? error;
  final bool isAdmin;
  final bool actionLoading;
  final VoidCallback onCreateFirstCash;
  final ValueChanged<AccountingCash> onCloseCash;

  @override
  Widget build(BuildContext context) {
    final cash = state?.cashSession;
    final requiresFirst = state?.requiresFirstCashSession ?? false;
    final pendingClosure = state?.pendingClosure ?? false;
    final status = _statusLabel(cash, requiresFirst);
    final statusColor = cash?.isOpen == true
        ? AppColors.successFg
        : cash?.isClosed == true
        ? AppColors.textMuted
        : AppColors.warningFg;
    final message =
        error ??
        (isAdmin && pendingClosure
            ? 'Hay una caja pendiente de cierre.'
            : requiresFirst
            ? (isAdmin
                  ? 'Crea la primera caja para iniciar el flujo diario.'
                  : 'La caja aún no ha sido inicializada por un administrador.')
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Caja del día'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: AppColors.infoFg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cash?.openedAt == null
                              ? 'Sin apertura registrada'
                              : 'Apertura ${Fmt.dateFull(cash!.openedAt!)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: error == null
                        ? AppColors.warningBg
                        : AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: error == null
                          ? AppColors.warningFg
                          : AppColors.errorFg,
                    ),
                  ),
                ),
              ],
              if (cash != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                _CashInfoRow(
                  label: 'Saldo inicial',
                  value: Fmt.lempira(cash.saldoInicialCaja),
                ),
                _CashInfoRow(
                  label: 'Dinero esperado en caja',
                  value: Fmt.lempira(cash.saldoFinalEstimado),
                ),
                if (cash.efectivoContado != null)
                  _CashInfoRow(
                    label: 'Efectivo total contado en caja',
                    value: Fmt.lempira(cash.efectivoContado!),
                  ),
                if (cash.diferenciaCaja != null)
                  _CashInfoRow(
                    label: 'Diferencia de caja',
                    value: Fmt.lempira(cash.diferenciaCaja!),
                    valueColor: cash.diferenciaCaja == 0
                        ? AppColors.successFg
                        : AppColors.errorFg,
                  ),
              ],
              if (isAdmin && requiresFirst) ...[
                const SizedBox(height: 14),
                AppButton(
                  label: 'Crear primera caja',
                  onPressed: actionLoading ? null : onCreateFirstCash,
                  icon: Icons.add_rounded,
                  size: AppButtonSize.sm,
                  loading: actionLoading,
                ),
              ] else if (isAdmin && cash?.isOpen == true) ...[
                const SizedBox(height: 14),
                AppButton(
                  label: 'Cerrar caja',
                  onPressed: actionLoading ? null : () => onCloseCash(cash!),
                  icon: Icons.lock_rounded,
                  size: AppButtonSize.sm,
                  loading: actionLoading,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(AccountingCash? cash, bool requiresFirst) {
    if (cash?.isOpen == true) return 'Caja abierta';
    if (cash?.isClosed == true) return 'Caja cerrada';
    if (requiresFirst) return 'Caja no inicializada';
    return 'Sin caja activa';
  }
}

class _CashInfoRow extends StatelessWidget {
  const _CashInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
          const SizedBox(width: 10),
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
    );
  }
}

class _CloseCashSummary extends StatelessWidget {
  const _CloseCashSummary({required this.report, required this.cash});

  final AccountingReport? report;
  final AccountingCash cash;

  @override
  Widget build(BuildContext context) {
    final resumen = report?.resumen;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _CloseSummaryRow(
            label: 'Saldo inicial de caja',
            value: Fmt.lempira(cash.saldoInicialCaja),
          ),
          _CloseSummaryRow(
            label: 'Total lavados del día',
            value: Fmt.lempira(resumen?.ingresosLavados ?? 0),
          ),
          _CloseSummaryRow(
            label: 'Total gastos del día',
            value: Fmt.lempira(resumen?.totalGastos ?? 0),
          ),
          _CloseSummaryRow(
            label: 'Adelantos entregados',
            value: Fmt.lempira(resumen?.adelantosEntregados ?? 0),
          ),
          _CloseSummaryRow(
            label: 'Nómina pagada',
            value: Fmt.lempira(resumen?.nominaNetaPagada ?? 0),
          ),
          _CloseSummaryRow(
            label: 'Abonos recibidos',
            value: Fmt.lempira(resumen?.abonosRecibidos ?? 0),
          ),
          _CloseSummaryRow(
            label: 'Movimiento neto de efectivo',
            value: Fmt.lempira(resumen?.movimientoNetoEfectivo ?? 0),
          ),
          const Divider(height: 18, color: AppColors.border),
          _CloseSummaryRow(
            label: 'Dinero esperado en caja',
            value: Fmt.lempira(cash.saldoFinalEstimado),
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _CloseSummaryRow extends StatelessWidget {
  const _CloseSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
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
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseCashHelpText extends StatelessWidget {
  const _CloseCashHelpText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ingrese todo el dinero físico que hay en caja al cerrar, no solo lo vendido en el día.',
      style: GoogleFonts.inter(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _CloseCashInputHelp extends StatelessWidget {
  const _CloseCashInputHelp();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Debe incluir el saldo inicial más ingresos, menos gastos, adelantos y nómina.',
      style: GoogleFonts.inter(
        fontSize: 11,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _DifferenceBox extends StatelessWidget {
  const _DifferenceBox({required this.difference});

  final double difference;

  @override
  Widget build(BuildContext context) {
    final color = _differenceColor(difference);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_differenceLabel(difference)}: ${Fmt.lempira(difference)}',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _PendingDaysBanner extends StatelessWidget {
  const _PendingDaysBanner({required this.summary});

  final PendingCashSummary summary;

  @override
  Widget build(BuildContext context) {
    final fecha = summary.fechaApertura;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningDot.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningDot.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.warningDot,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fecha != null
                      ? 'Caja abierta desde el ${Fmt.dateFull(fecha)}'
                      : 'Caja con varios días pendientes de cierre',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.diasAbiertos} días pendientes de cierre · '
            '${summary.cantidadLavados} lavados por ${Fmt.lempira(summary.montoLavados)}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          if (summary.porDia.length > 1) ...[
            const SizedBox(height: 8),
            for (final day in summary.porDia)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day.fecha != null ? Fmt.dateShort(day.fecha!) : '—',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '${day.cantidad} lavados · ${Fmt.lempira(day.total)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DayWashesList extends StatelessWidget {
  const _DayWashesList({required this.washes});

  final List<WashItem> washes;

  @override
  Widget build(BuildContext context) {
    return _DetailListShell(
      title: 'Lavados pendientes de cierre',
      empty: 'Sin lavados registrados.',
      children: [
        for (final wash in washes)
          _SmallDetailRow(
            title: '${wash.timeFormatted} · ${wash.vehicleTypeName}',
            subtitle: wash.displayService,
            value: Fmt.lempira(wash.price),
          ),
      ],
    );
  }
}

class _DayExpensesList extends StatelessWidget {
  const _DayExpensesList({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return _DetailListShell(
      title: 'Gastos del día',
      empty: 'Sin gastos registrados.',
      children: [
        for (final expense in expenses)
          _SmallDetailRow(
            title: _expenseTitle(expense),
            subtitle: Fmt.dateFull(expense.expenseDate),
            value: Fmt.lempira(expense.total),
          ),
      ],
    );
  }
}

class _DetailListShell extends StatelessWidget {
  const _DetailListShell({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(
              empty,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _SmallDetailRow extends StatelessWidget {
  const _SmallDetailRow({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
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
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

String _expenseTitle(Expense expense) {
  if (expense.items.isNotEmpty) {
    return expense.items.first.description;
  }
  if (expense.supplierName.isNotEmpty) return expense.supplierName;
  return 'Gasto #${expense.id}';
}

String _differenceLabel(double difference) {
  if (difference < 0) return 'Faltante de caja';
  if (difference > 0) return 'Sobrante de caja';
  return 'Caja cuadrada';
}

Color _differenceColor(double difference) {
  if (difference < 0) return AppColors.errorFg;
  if (difference > 0) return AppColors.warningFg;
  return AppColors.successFg;
}

// ─── Register wash CTA ────────────────────────────────────────────────────────

class _RegisterWashBtn extends StatelessWidget {
  const _RegisterWashBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withAlpha(70),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.local_car_wash_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registrar lavado',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '3 toques · sin formularios largos',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white60,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick access card ────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent washes ────────────────────────────────────────────────────────────

class _RecentWashes extends StatelessWidget {
  const _RecentWashes({required this.washes});
  final List<WashItem> washes;

  @override
  Widget build(BuildContext context) {
    if (washes.isEmpty) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Icon(
                  Icons.local_car_wash_outlined,
                  size: 30,
                  color: AppColors.textMuted2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Aún no hay lavados registrados hoy',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final shown = washes.take(3).toList();

    return Column(
      children: [
        for (int i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _WashRow(wash: shown[i]),
        ],
      ],
    );
  }
}

class _WashRow extends StatelessWidget {
  const _WashRow({required this.wash});
  final WashItem wash;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_car_wash_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wash.displayService,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  wash.vehicleTypeName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.lempira(wash.price),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wash.timeFormatted,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  StatusBadge.wash(
                    wash.isCompleted
                        ? WashStatus.completado
                        : WashStatus.anulado,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
