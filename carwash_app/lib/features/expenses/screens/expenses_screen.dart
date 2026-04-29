import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/expense_model.dart';
import '../providers/expenses_provider.dart';
import '../services/expense_service.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpensesProvider()..load(),
      child: const _ExpensesBody(),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ExpensesBody extends StatefulWidget {
  const _ExpensesBody();

  @override
  State<_ExpensesBody> createState() => _ExpensesBodyState();
}

class _ExpensesBodyState extends State<_ExpensesBody> {
  Future<void> _goToCreateExpense() async {
    final refreshed = await context.push<bool>(AppRouter.createExpense);
    debugPrint('[ExpensesScreen] push<bool> returned: $refreshed');
    if ((refreshed ?? false) && mounted) {
      context.read<ExpensesProvider>().refresh();
    }
  }

  void _showDetail(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseDetailSheet(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExpensesProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            total:            vm.total,
            totalAmount:      vm.totalAmount,
            onCreateExpense:  _goToCreateExpense,
          ),
          const _Filters(),
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ExpensesProvider vm) {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (vm.error != null) {
      return _ErrorView(message: vm.error!, onRetry: vm.load);
    }
    if (vm.expenses.isEmpty) {
      return _EmptyView(onCreateExpense: _goToCreateExpense);
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: vm.expenses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final expense = vm.expenses[i];
          return _ExpenseCard(
            expense: expense,
            onTap: () => _showDetail(context, expense),
          );
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.totalAmount,
    required this.onCreateExpense,
  });

  final int total;
  final double totalAmount;
  final VoidCallback onCreateExpense;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total gastos · ${Fmt.lempira(totalAmount)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onCreateExpense,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Registrar',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filters ──────────────────────────────────────────────────────────────────

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExpensesProvider>();

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Hoy',
              active: vm.dateFilter == ExpenseDateFilter.today,
              onTap: () => context.read<ExpensesProvider>().setDateFilter(ExpenseDateFilter.today),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Todos',
              active: vm.dateFilter == ExpenseDateFilter.all,
              onTap: () => context.read<ExpensesProvider>().setDateFilter(ExpenseDateFilter.all),
            ),
            const SizedBox(width: 16),
            _FilterChip(
              label: 'Activos',
              active: vm.statusFilter == 'activo',
              onTap: () => context.read<ExpensesProvider>().setStatusFilter(
                vm.statusFilter == 'activo' ? null : 'activo',
              ),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Anulados',
              active: vm.statusFilter == 'anulado',
              onTap: () => context.read<ExpensesProvider>().setStatusFilter(
                vm.statusFilter == 'anulado' ? null : 'anulado',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.primary : Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ─── Expense card ─────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final anulado = !expense.isActive;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: anulado ? AppColors.errorBg : AppColors.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: anulado ? AppColors.errorFg : AppColors.warningDot,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.supplierName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: anulado ? AppColors.textMuted : AppColors.textPrimary,
                    decoration: anulado ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.invoiceLabel}: ${expense.invoiceDisplay}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.dateShort(expense.expenseDate),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted2,
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
                Fmt.lempira(expense.total),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: anulado ? AppColors.textMuted : AppColors.textPrimary,
                  decoration: anulado ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              StatusBadge.raw(
                label: expense.status,
                bg:    expense.isActive ? AppColors.successBg : AppColors.errorBg,
                fg:    expense.isActive ? AppColors.successFg : AppColors.errorFg,
                dot:   expense.isActive ? AppColors.successDot : AppColors.errorDot,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreateExpense});
  final VoidCallback onCreateExpense;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 52, color: AppColors.textMuted2),
            const SizedBox(height: 14),
            Text(
              'No hay gastos registrados',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cambia los filtros o registra un nuevo gasto.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Registrar gasto',
              onPressed: onCreateExpense,
              icon: Icons.add_rounded,
              fullWidth: false,
              size: AppButtonSize.sm,
            ),
          ],
        ),
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
            const Icon(Icons.wifi_off_rounded, size: 44, color: AppColors.textMuted2),
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

// ─── Detail bottom sheet ──────────────────────────────────────────────────────

class _ExpenseDetailSheet extends StatefulWidget {
  const _ExpenseDetailSheet({required this.expense});
  final Expense expense;

  @override
  State<_ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends State<_ExpenseDetailSheet> {
  bool _loadingItems = true;
  List<ExpenseItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final full = await ExpenseService.getExpense(widget.expense.id);
      if (mounted) setState(() { _items = full.items; _loadingItems = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gasto #${e.id}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      StatusBadge.raw(
                        label: e.status,
                        bg:    e.isActive ? AppColors.successBg : AppColors.errorBg,
                        fg:    e.isActive ? AppColors.successFg : AppColors.errorFg,
                        dot:   e.isActive ? AppColors.successDot : AppColors.errorDot,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border, height: 1),
                ],
              ),
            ),
            // scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Proveedor',   value: e.supplierName),
                    _DetailRow(label: e.invoiceLabel, value: e.invoiceDisplay),
                    _DetailRow(label: 'Fecha',        value: Fmt.dateShort(e.expenseDate)),
                    if (e.userName != null)
                      _DetailRow(label: 'Registrado por', value: e.userName!),
                    if (e.notes != null && e.notes!.isNotEmpty)
                      _DetailRow(label: 'Notas', value: e.notes!),
                    const SizedBox(height: 16),
                    // Items section
                    Text(
                      'ÍTEMS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingItems)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (_items.isEmpty)
                      Text(
                        'Sin ítems',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      )
                    else
                      for (final item in _items) _ItemRow(item: item),
                    const SizedBox(height: 16),
                    // Totals
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _TotalRow(label: 'Subtotal', value: e.subtotal),
                          const SizedBox(height: 6),
                          _TotalRow(label: 'ISV',      value: e.taxAmount),
                          const Divider(color: AppColors.border, height: 16),
                          _TotalRow(
                            label: 'Total',
                            value: e.total,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
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
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final ExpenseItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} × ${Fmt.lempira(item.unitPrice)} · ISV ${item.taxRate.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Fmt.lempira(item.total),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false});
  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: bold ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        Text(
          Fmt.lempira(value),
          style: GoogleFonts.inter(
            fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
