import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../auth/providers/auth_provider.dart';
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
          const ReportsScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: _currentTab,
        onTap: _onTabTap,
      ),
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

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final auth = context.watch<AuthProvider>();

    return Column(
      children: [
        _Header(user: auth.user?.name ?? '', report: home.report),
        Expanded(child: _buildBody(context, home)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, HomeProvider home) {
    if (home.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (home.error != null) {
      return _ErrorView(message: home.error!, onRetry: home.loadToday);
    }
    return _Content(
      report: home.report,
      recentWashes: home.recentWashes,
      onTabChange: widget.onTabChange,
      onRegisterWash: _goToRegisterWash,
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
    required this.recentWashes,
    required this.onTabChange,
    required this.onRegisterWash,
  });

  final AccountingReport? report;
  final List<WashItem> recentWashes;
  final ValueChanged<NavTab> onTabChange;
  final VoidCallback onRegisterWash;

  @override
  Widget build(BuildContext context) {
    final r = report?.resumen;
    final washCount = report?.lavados.cantidad ?? 0;
    final flujo = r?.flujoEfectivoEstimado ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards 2×2
          Row(children: [
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
          ]),
          const SizedBox(height: 10),
          Row(children: [
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
                label: 'Flujo est.',
                value: Fmt.lempira(flujo),
                icon: flujo >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                iconColor: flujo >= 0 ? AppColors.successFg : AppColors.errorFg,
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Register wash CTA
          _RegisterWashBtn(onTap: onRegisterWash),

          const SizedBox(height: 16),

          // Quick access 2×2
          SectionHeader(title: 'Accesos rápidos'),
          const SizedBox(height: 10),
          Row(children: [
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
          ]),

          const SizedBox(height: 16),

          // Recent washes
          SectionHeader(title: 'Últimos lavados'),
          const SizedBox(height: 10),
          _RecentWashes(washes: recentWashes),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
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
                    wash.isCompleted ? WashStatus.completado : WashStatus.anulado,
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
