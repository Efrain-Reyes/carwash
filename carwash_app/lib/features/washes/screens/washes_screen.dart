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
import '../models/wash_item.dart';
import '../providers/washes_provider.dart';

class WashesScreen extends StatelessWidget {
  const WashesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WashesProvider()..load(),
      child: const _WashesBody(),
    );
  }
}

// ─── Body (StatefulWidget for push/mounted logic) ─────────────────────────────

class _WashesBody extends StatefulWidget {
  const _WashesBody();

  @override
  State<_WashesBody> createState() => _WashesBodyState();
}

class _WashesBodyState extends State<_WashesBody> {
  Future<void> _goToRegisterWash() async {
    final refreshed = await context.push<bool>(AppRouter.registerWash);
    debugPrint('[WashesScreen] push<bool> returned: $refreshed');
    if ((refreshed ?? false) && mounted) {
      context.read<WashesProvider>().refresh();
    }
  }

  void _showDetail(BuildContext context, WashItem wash) {
    final vm = context.read<WashesProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: _WashDetailSheet(wash: wash),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WashesProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            total:           vm.total,
            ingresos:        vm.totalIngresos,
            onRegisterWash:  _goToRegisterWash,
          ),
          const _Filters(),
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WashesProvider vm) {
    if (vm.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (vm.error != null) {
      return _ErrorView(message: vm.error!, onRetry: vm.load);
    }
    if (vm.washes.isEmpty) {
      return _EmptyView(onRegisterWash: _goToRegisterWash);
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: vm.washes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final wash = vm.washes[i];
          return _WashCard(
            wash: wash,
            onTap: () => _showDetail(context, wash),
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
    required this.ingresos,
    required this.onRegisterWash,
  });

  final int total;
  final double ingresos;
  final VoidCallback onRegisterWash;

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
                      'Lavados',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total lavados · ${Fmt.lempira(ingresos)}',
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
                onTap: onRegisterWash,
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
    final vm = context.watch<WashesProvider>();

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Hoy',
              active: vm.dateFilter == WashDateFilter.today,
              onTap: () => context.read<WashesProvider>().setDateFilter(WashDateFilter.today),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Todos',
              active: vm.dateFilter == WashDateFilter.all,
              onTap: () => context.read<WashesProvider>().setDateFilter(WashDateFilter.all),
            ),
            const SizedBox(width: 16),
            _FilterChip(
              label: 'Completados',
              active: vm.statusFilter == 'completado',
              onTap: () => context.read<WashesProvider>().setStatusFilter(
                vm.statusFilter == 'completado' ? null : 'completado',
              ),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Anulados',
              active: vm.statusFilter == 'anulado',
              onTap: () => context.read<WashesProvider>().setStatusFilter(
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

// ─── Wash card ────────────────────────────────────────────────────────────────

class _WashCard extends StatelessWidget {
  const _WashCard({required this.wash, required this.onTap});

  final WashItem wash;
  final VoidCallback onTap;

  static IconData _iconFor(String vehicleType) {
    final n = vehicleType.toLowerCase();
    if (n.contains('moto')) return Icons.two_wheeler_rounded;
    if (n.contains('camio')) return Icons.local_shipping_rounded;
    return Icons.directions_car_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final anulado = wash.isAnulado;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: anulado ? AppColors.errorBg : AppColors.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconFor(wash.vehicleTypeName),
              size: 20,
              color: anulado ? AppColors.errorFg : AppColors.accent,
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
                    color: anulado ? AppColors.textMuted : AppColors.textPrimary,
                    decoration: anulado ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${wash.vehicleTypeName} · #${wash.id}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${wash.dateTimeFormatted}${wash.userName != null ? ' · ${wash.userName}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: anulado ? AppColors.textMuted : AppColors.textPrimary,
                  decoration: anulado ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              StatusBadge.wash(
                wash.isCompleted ? WashStatus.completado : WashStatus.anulado,
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
  const _EmptyView({required this.onRegisterWash});
  final VoidCallback onRegisterWash;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_car_wash_outlined,
              size: 52,
              color: AppColors.textMuted2,
            ),
            const SizedBox(height: 14),
            Text(
              'No hay lavados registrados',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cambia los filtros o registra un nuevo lavado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Registrar lavado',
              onPressed: onRegisterWash,
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

class _WashDetailSheet extends StatefulWidget {
  const _WashDetailSheet({required this.wash});
  final WashItem wash;

  @override
  State<_WashDetailSheet> createState() => _WashDetailSheetState();
}

class _WashDetailSheetState extends State<_WashDetailSheet> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmCancel() async {
    _notesController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Anular lavado',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Seguro que deseas anular este lavado? Esta acción no se puede deshacer.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Motivo (opcional)',
                hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted2,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.surface2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: GoogleFonts.inter(fontSize: 13),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Anular',
              style: GoogleFonts.inter(
                color: AppColors.errorFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final vm        = context.read<WashesProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await vm.cancelWash(widget.wash.id, notes: _notesController.text);

    if (!mounted) return;
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Lavado anulado correctamente'
              : 'No se pudo anular el lavado. Intenta de nuevo.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: ok ? AppColors.successFg : AppColors.errorFg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm   = context.watch<WashesProvider>();
    final wash = widget.wash;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
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
              // title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lavado #${wash.id}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  StatusBadge.wash(
                    wash.isCompleted ? WashStatus.completado : WashStatus.anulado,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              // detail rows
              _DetailRow(label: 'Servicio',  value: wash.displayService),
              _DetailRow(label: 'Vehículo',  value: wash.vehicleTypeName),
              _DetailRow(label: 'Precio',    value: Fmt.lempira(wash.price)),
              _DetailRow(label: 'Fecha',     value: wash.dateTimeFormatted),
              if (wash.userName != null)
                _DetailRow(label: 'Registrado por', value: wash.userName!),
              if (wash.notes != null && wash.notes!.isNotEmpty)
                _DetailRow(label: 'Notas', value: wash.notes!),
              const SizedBox(height: 20),
              // action
              if (wash.isCompleted)
                AppButtonSecondary(
                  label: 'Anular lavado',
                  icon: Icons.block_rounded,
                  onPressed: vm.cancelling ? null : _confirmCancel,
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Este lavado ya fue anulado',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
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
