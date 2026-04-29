import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/advance_model.dart';
import '../services/payroll_service.dart';

AdvanceStatus _toAdvanceStatus(String s) => switch (s) {
  'pendiente' => AdvanceStatus.pendiente,
  'parcialmente_pagado' => AdvanceStatus.parcialmentePagado,
  'pagado' => AdvanceStatus.pagado,
  _ => AdvanceStatus.anulado,
};

class _AdvanceFilter {
  const _AdvanceFilter(this.value, this.label);

  final String? value;
  final String label;
}

class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key});

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends State<AdvancesScreen> {
  List<Advance> _advances = [];
  String? _statusFilter;
  bool _loading = true;
  String? _error;
  bool _didChange = false;

  static const _filters = [
    _AdvanceFilter(null, 'Todos'),
    _AdvanceFilter('pendiente', 'Pendientes'),
    _AdvanceFilter('parcialmente_pagado', 'Parciales'),
    _AdvanceFilter('pagado', 'Pagados'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    debugPrint('[AdvancesScreen] Loading advances...');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await PayrollService.getAdvances(status: _statusFilter);
      debugPrint('[AdvancesScreen] Advances count: ${all.length}');
      if (!mounted) return;
      setState(() {
        _advances = all;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AdvancesScreen] Error: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cargar los adelantos.\nVerifica tu red e intenta de nuevo.';
        _loading = false;
      });
    }
  }

  void _setFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() {
      _statusFilter = status;
    });
    _load();
  }

  void _goBack() => context.pop(_didChange);

  Future<void> _goToNew() async {
    final done = await context.push<bool>(AppRouter.registerAdvance);
    if ((done ?? false) && mounted) {
      _didChange = true;
      _load();
    }
  }

  Future<void> _goToDetail(Advance advance) async {
    final changed = await context.push<bool>(
      AppRouter.advanceDetail(advance.id),
      extra: advance,
    );
    if ((changed ?? false) && mounted) {
      _didChange = true;
      _load();
    }
  }

  double get _totalBalance => _advances.fold(0.0, (s, a) => s + a.balance);

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
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adelantos',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (!_loading && _error == null)
                      Text(
                        '${_advances.length} adelantos · '
                        'Saldo ${Fmt.lempira(_totalBalance)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
              ),
              _HeaderAction(onTap: _goToNew),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final selected = _statusFilter == filter.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: filter.label,
                active: selected,
                onTap: () => _setFilter(filter.value),
              ),
            );
          }).toList(),
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
    if (_advances.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 44,
              color: AppColors.textMuted2,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay adelantos registrados',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Registrar adelanto',
              onPressed: _goToNew,
              icon: Icons.add_rounded,
              fullWidth: false,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        itemCount: _advances.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _AdvanceCard(
          advance: _advances[i],
          onTap: () => _goToDetail(_advances[i]),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              'Nuevo',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

// ─── Advance card ─────────────────────────────────────────────────────────────

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.advance, required this.onTap});

  final Advance advance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  advance.employeeName.isNotEmpty
                      ? advance.employeeName
                      : 'Empleado #${advance.employeeId}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusBadge.advance(_toAdvanceStatus(advance.status)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AmountCol(
                  label: 'Monto original',
                  value: Fmt.lempira(advance.amount),
                  highlight: false,
                ),
              ),
              Expanded(
                child: _AmountCol(
                  label: 'Saldo pendiente',
                  value: Fmt.lempira(advance.balance),
                  highlight: advance.isPending || advance.isPartial,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fecha',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    Fmt.dateShort(advance.advanceDate),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (advance.amount > 0 && !advance.isPaid) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: advance.progress,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.accent,
                ),
              ),
            ),
          ],
          if (advance.notes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 13,
                  color: AppColors.textMuted2,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    advance.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountCol extends StatelessWidget {
  const _AmountCol({
    required this.label,
    required this.value,
    required this.highlight,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.warningFg : AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
