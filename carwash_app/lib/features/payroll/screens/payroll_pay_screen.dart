import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/employee_model.dart';
import '../models/payroll_models.dart';
import '../services/payroll_service.dart';

class PayrollPayScreen extends StatefulWidget {
  const PayrollPayScreen({super.key});

  @override
  State<PayrollPayScreen> createState() => _PayrollPayScreenState();
}

class _PayrollPayScreenState extends State<PayrollPayScreen> {
  final _daysCtrl = TextEditingController();
  final _extraCtrl = TextEditingController(text: '0');
  final _advanceDiscountCtrl = TextEditingController(text: '0');
  final _otherDeductionsCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  List<Employee> _employees = [];
  Employee? _selectedEmployee;
  PayrollPreview? _preview;

  DateTime _paymentDate = DateTime.now();
  late DateTime _startDate;
  late DateTime _endDate;

  bool _loadingEmployees = true;
  bool _loadingPreview = false;
  bool _saving = false;
  String? _employeeError;
  String? _previewError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = today.subtract(Duration(days: today.weekday - 1));
    _endDate = _startDate.add(const Duration(days: 6));
    for (final ctrl in [
      _daysCtrl,
      _extraCtrl,
      _advanceDiscountCtrl,
      _otherDeductionsCtrl,
    ]) {
      ctrl.addListener(() => setState(() => _formError = null));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEmployees());
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _extraCtrl.dispose();
    _advanceDiscountCtrl.dispose();
    _otherDeductionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _employeeError = null;
      _previewError = null;
    });
    try {
      final list = await PayrollService.getEmployees();
      final active = list.where((e) => e.isActive).toList();
      final previousId = _selectedEmployee?.id;
      final nextEmployee = active.isEmpty
          ? null
          : active.firstWhere(
              (e) => e.id == previousId,
              orElse: () => active.first,
            );
      if (!mounted) return;
      setState(() {
        _employees = active;
        _selectedEmployee = null;
        _preview = null;
        _loadingEmployees = false;
      });
      if (nextEmployee != null) {
        await _selectEmployee(nextEmployee);
      }
    } catch (e) {
      debugPrint('[PayrollPayScreen] Error loading employees: $e');
      if (!mounted) return;
      setState(() {
        _employeeError =
            'No se pudo cargar los trabajadores.\nVerifica tu red e intenta de nuevo.';
        _loadingEmployees = false;
      });
    }
  }

  Future<void> _selectEmployee(Employee? employee) async {
    if (employee == null) return;
    _advanceDiscountCtrl.text = '0';
    setState(() {
      _selectedEmployee = employee;
      _preview = null;
      _loadingPreview = true;
      _previewError = null;
      _formError = null;
    });

    try {
      final preview = await PayrollService.getPayrollPreview(employee.id);
      if (!mounted) return;
      final salary = preview.currentSalary;
      _daysCtrl.text = salary?.workDaysPerPeriod.toString() ?? '';
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (e) {
      debugPrint('[PayrollPayScreen] Error loading preview: $e');
      if (!mounted) return;
      setState(() {
        _previewError =
            'No se pudo cargar el preview de nómina.\nIntenta de nuevo.';
        _loadingPreview = false;
      });
    }
  }

  double get _daysWorked => double.tryParse(_daysCtrl.text.trim()) ?? 0;
  double get _extraPayments => double.tryParse(_extraCtrl.text.trim()) ?? 0;
  double get _advanceDiscount =>
      double.tryParse(_advanceDiscountCtrl.text.trim()) ?? 0;
  double get _otherDeductions =>
      double.tryParse(_otherDeductionsCtrl.text.trim()) ?? 0;

  EmployeeSalary? get _salary => _preview?.currentSalary;
  double get _grossAmount => _daysWorked * (_salary?.dailyRate ?? 0);
  double get _netAmount =>
      _grossAmount + _extraPayments - _advanceDiscount - _otherDeductions;
  double get _pendingAdvanceBalance =>
      _preview?.pendingAdvances.totalBalance ?? 0;

  String? _validationMessage() {
    final employee = _selectedEmployee;
    final preview = _preview;
    final salary = _salary;

    if (_saving || _loadingEmployees || _loadingPreview) return null;
    if (employee == null) return 'Selecciona un trabajador.';
    if (preview == null) return 'Carga el preview del trabajador.';
    if (salary == null || salary.id <= 0) {
      return 'Este trabajador no tiene sueldo vigente.';
    }
    if (_endDate.isBefore(_startDate)) {
      return 'La fecha fin del periodo debe ser igual o posterior al inicio.';
    }
    if (_daysWorked <= 0) return 'Ingresa los días trabajados.';
    if (_daysWorked > salary.workDaysPerPeriod) {
      return 'Los días trabajados no pueden superar ${salary.workDaysPerPeriod}.';
    }
    if (_advanceDiscount > _pendingAdvanceBalance) {
      return 'El descuento de adelantos supera el saldo pendiente.';
    }
    if (_pendingAdvanceBalance <= 0 && _advanceDiscount > 0) {
      return 'Este trabajador no tiene adelantos pendientes.';
    }
    if (_netAmount < 0) return 'El total neto no puede ser negativo.';
    return null;
  }

  bool get _canSubmit => !_saving && _validationMessage() == null;

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
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
    if (picked != null) setState(() => onSelected(picked));
  }

  void _setAdvanceDiscount(double value) {
    final clamped = value.clamp(0, _pendingAdvanceBalance).toDouble();
    _advanceDiscountCtrl.text = _formatInputAmount(clamped);
  }

  String _formatInputAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  Future<void> _save() async {
    final validation = _validationMessage();
    if (validation != null) {
      setState(() => _formError = validation);
      return;
    }

    final employee = _selectedEmployee!;
    final salary = _salary!;
    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final period = await PayrollService.createPayrollPeriod(
        startDate: Fmt.dateApi(_startDate),
        endDate: Fmt.dateApi(_endDate),
        notes:
            'Periodo del ${Fmt.dateShort(_startDate)} al ${Fmt.dateShort(_endDate)}',
      );

      final payment = await PayrollService.createPayrollPayment(
        periodId: period.id,
        employeeId: employee.id,
        salaryHistoryId: salary.id,
        daysWorked: _daysWorked,
        advanceDiscount: _advanceDiscount,
        extraPayments: _extraPayments,
        otherDeductions: _otherDeductions,
        paymentDate: Fmt.dateApi(_paymentDate),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await PayrollService.confirmPayrollPayment(payment.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nómina pagada correctamente'),
          backgroundColor: AppColors.successFg,
        ),
      );
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = _extractError(e);
        _saving = false;
      });
    } catch (e) {
      debugPrint('[PayrollPayScreen] Unexpected save error: $e');
      if (!mounted) return;
      setState(() {
        _formError = 'No se pudo pagar la nómina. Intenta de nuevo.';
        _saving = false;
      });
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
    }
    return 'No se pudo pagar la nómina. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final showFooter =
        !_loadingEmployees && _employeeError == null && _employees.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          if (showFooter) _buildFooter(),
        ],
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
                onPressed: _saving ? null : () => context.pop(false),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  'Pagar nómina',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingEmployees) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_employeeError != null) {
      return _CenteredState(
        icon: Icons.wifi_off_rounded,
        message: _employeeError!,
        buttonLabel: 'Reintentar',
        onPressed: _loadEmployees,
      );
    }

    if (_employees.isEmpty) {
      return const _CenteredState(
        icon: Icons.group_off_rounded,
        message: 'No hay trabajadores activos para pagar nómina.',
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadEmployees,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmployeeSelector(),
            const SizedBox(height: 14),
            if (_loadingPreview)
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
            else if (_previewError != null)
              _InlineError(
                message: _previewError!,
                onRetry: () {
                  final employee = _selectedEmployee;
                  if (employee != null) _selectEmployee(employee);
                },
              )
            else if (_preview != null) ...[
              _buildSalaryPreview(),
              const SizedBox(height: 14),
              _buildAdvancesPreview(),
              const SizedBox(height: 14),
              _buildPeriodSection(),
              const SizedBox(height: 14),
              _buildCalculationSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Trabajador'),
        const SizedBox(height: 8),
        AppCard(
          child: DropdownButton<Employee>(
            value: _selectedEmployee,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: _employees
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving ? null : _selectEmployee,
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryPreview() {
    final preview = _preview!;
    final salary = preview.currentSalary;
    if (salary == null) {
      return const _InlineError(
        message: 'Este trabajador no tiene sueldo vigente.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Sueldo vigente'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.employee.fullName,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Sueldo',
                      value: Fmt.lempira(salary.salary),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Frecuencia',
                      value: salary.frequencyLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Días periodo',
                      value: '${salary.workDaysPerPeriod}',
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Valor diario',
                      value: Fmt.lempira(salary.dailyRate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancesPreview() {
    final preview = _preview!;
    final salary = _salary;
    final advances = preview.pendingAdvances.advances;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Adelantos pendientes'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (advances.isEmpty) ...[
                Text(
                  'Este trabajador no tiene adelantos pendientes.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Saldo pendiente',
                        value: Fmt.lempira(_pendingAdvanceBalance),
                        color: AppColors.warningFg,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Adelantos',
                        value: '${advances.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...advances
                    .take(3)
                    .map(
                      (advance) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${Fmt.dateShort(advance.advanceDate)} · ${advance.status}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            Text(
                              Fmt.lempira(advance.balance),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChoiceChipButton(
                      label: 'Sin descuento',
                      onTap: () => _setAdvanceDiscount(0),
                    ),
                    if (salary != null)
                      _ChoiceChipButton(
                        label: '1 día',
                        onTap: () => _setAdvanceDiscount(salary.dailyRate),
                      ),
                    if (salary != null)
                      _ChoiceChipButton(
                        label: '2 días',
                        onTap: () => _setAdvanceDiscount(salary.dailyRate * 2),
                      ),
                    _ChoiceChipButton(
                      label: 'Todo saldo',
                      enabled:
                          _pendingAdvanceBalance > 0 &&
                          _pendingAdvanceBalance <= _grossAmount,
                      onTap: () => _setAdvanceDiscount(_pendingAdvanceBalance),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              AppTextField(
                label: 'DESCUENTO DE ADELANTO (L)',
                hint: '0.00',
                controller: _advanceDiscountCtrl,
                enabled: advances.isNotEmpty && !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Periodo'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              _DateRow(
                label: 'Fecha de pago',
                value: Fmt.dateFull(_paymentDate),
                onTap: () => _pickDate(
                  initialDate: _paymentDate,
                  onSelected: (d) => _paymentDate = d,
                ),
              ),
              const SizedBox(height: 12),
              _DateRow(
                label: 'Inicio del periodo',
                value: Fmt.dateFull(_startDate),
                onTap: () => _pickDate(
                  initialDate: _startDate,
                  onSelected: (d) => _startDate = d,
                ),
              ),
              const SizedBox(height: 12),
              _DateRow(
                label: 'Fin del periodo',
                value: Fmt.dateFull(_endDate),
                onTap: () => _pickDate(
                  initialDate: _endDate,
                  onSelected: (d) => _endDate = d,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalculationSection() {
    final validation = _validationMessage();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Cálculo de pago'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              AppTextField(
                label: 'DÍAS TRABAJADOS',
                hint: 'Ej: 6',
                controller: _daysCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'PAGOS EXTRA (L)',
                hint: '0.00',
                controller: _extraCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'OTROS DESCUENTOS (L)',
                hint: '0.00',
                controller: _otherDeductionsCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'NOTAS (OPCIONAL)',
                hint: 'Ej: Pago semanal',
                controller: _notesCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 14),
              _TotalRow(label: 'Sueldo bruto', value: _grossAmount),
              _TotalRow(label: 'Pagos extra', value: _extraPayments),
              _TotalRow(label: 'Descuento adelanto', value: -_advanceDiscount),
              _TotalRow(label: 'Otros descuentos', value: -_otherDeductions),
              const SizedBox(height: 8),
              _NetTotal(value: _netAmount),
              if (validation != null || _formError != null) ...[
                const SizedBox(height: 12),
                _ErrorText(message: _formError ?? validation!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neto a pagar',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Fmt.lempira(_netAmount),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: _netAmount < 0
                            ? AppColors.errorFg
                            : AppColors.successFg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 178,
                child: AppButton(
                  label: 'Confirmar',
                  onPressed: _canSubmit ? _save : null,
                  loading: _saving,
                  icon: Icons.check_circle_rounded,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted2),
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
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: buttonLabel!,
                onPressed: onPressed,
                icon: Icons.refresh_rounded,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ErrorText(message: message),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Reintentar',
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
              size: AppButtonSize.sm,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.errorFg,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.errorFg,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent.withAlpha(18) : AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: enabled ? AppColors.primary : AppColors.textMuted2,
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
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

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final double value;

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
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            Fmt.lempira(value),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: value < 0 ? AppColors.errorFg : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetTotal extends StatelessWidget {
  const _NetTotal({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: value < 0 ? AppColors.errorBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total neto a pagar',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: value < 0 ? AppColors.errorFg : AppColors.successFg,
              ),
            ),
          ),
          Text(
            Fmt.lempira(value),
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: value < 0 ? AppColors.errorFg : AppColors.successFg,
            ),
          ),
        ],
      ),
    );
  }
}
