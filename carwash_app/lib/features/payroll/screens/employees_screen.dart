import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/employee_model.dart';
import '../services/payroll_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Employee> _employees = [];
  bool _loading = true;
  String? _error;
  bool _didChange = false; // propaga refresh al PayrollScreen al volver

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    debugPrint('[EmployeesScreen] Loading employees...');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PayrollService.getEmployees();
      debugPrint('[EmployeesScreen] Employees count: ${list.length}');
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[EmployeesScreen] Error loading employees: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cargar los trabajadores.\nVerifica tu red e intenta de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _goToNew() async {
    final created = await context.push<bool>(AppRouter.registerEmployee);
    if ((created ?? false) && mounted) {
      _didChange = true;
      _load();
    }
  }

  Future<void> _goToDetail(Employee emp) async {
    final changed = await context.push<bool>(
      AppRouter.employeeDetail(emp.id),
      extra: emp,
    );
    if ((changed ?? false) && mounted) {
      _didChange = true;
      _load();
    }
  }

  void _goBack() => context.pop(_didChange);

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
            Expanded(child: _buildBody()),
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
                  'Trabajadores',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HeaderNewButton(onTap: _goToNew),
            ],
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
    if (_employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_off_rounded,
              size: 44,
              color: AppColors.textMuted2,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay trabajadores registrados',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Registrar trabajador',
              onPressed: _goToNew,
              icon: Icons.person_add_rounded,
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
        itemCount: _employees.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _EmployeeCard(
          employee: _employees[i],
          onTap: () => _goToDetail(_employees[i]),
        ),
      ),
    );
  }
}

// ─── Employee card ────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.onTap});

  final Employee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final salary = employee.currentSalary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            letter: employee.firstName.isNotEmpty
                ? employee.firstName[0].toUpperCase()
                : '?',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.fullName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge.raw(
                      label: employee.isActive ? 'activo' : 'inactivo',
                      bg: employee.isActive
                          ? AppColors.successBg
                          : AppColors.errorBg,
                      fg: employee.isActive
                          ? AppColors.successFg
                          : AppColors.errorFg,
                      dot: employee.isActive
                          ? AppColors.successDot
                          : AppColors.errorDot,
                    ),
                  ],
                ),
                if (employee.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    employee.phone!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (salary != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                        label: Fmt.lempira(salary.salary),
                        icon: Icons.payments_outlined,
                      ),
                      _InfoChip(
                        label: salary.frequencyLabel,
                        icon: Icons.calendar_month_outlined,
                      ),
                      _InfoChip(
                        label: '${Fmt.lempira(salary.dailyRate)}/día',
                        icon: Icons.today_outlined,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(18),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

class _HeaderNewButton extends StatelessWidget {
  const _HeaderNewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Nuevo trabajador',
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
