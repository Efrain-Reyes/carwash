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
import '../services/payroll_service.dart';

class RegisterAdvanceScreen extends StatefulWidget {
  const RegisterAdvanceScreen({super.key, this.employee});
  final Employee? employee;

  @override
  State<RegisterAdvanceScreen> createState() => _RegisterAdvanceScreenState();
}

class _RegisterAdvanceScreenState extends State<RegisterAdvanceScreen> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Employee> _employees = [];
  Employee? _selectedEmployee;
  DateTime _date = DateTime.now();
  bool _loadingEmployees = false;
  bool _saving = false;
  String? _error;
  String? _employeeLoadError;

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _selectedEmployee = widget.employee;
    } else {
      _loadEmployees();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _employeeLoadError = null;
    });
    try {
      final list = await PayrollService.getEmployees();
      if (!mounted) return;
      setState(() {
        _employees = list.where((e) => e.isActive).toList();
        _loadingEmployees = false;
      });
    } catch (e) {
      debugPrint('[RegisterAdvanceScreen] Error loading employees: $e');
      if (!mounted) return;
      setState(() {
        _employeeLoadError = 'No se pudo cargar los trabajadores.';
        _loadingEmployees = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool get _canSave =>
      !_saving &&
      _selectedEmployee != null &&
      (double.tryParse(_amountCtrl.text.trim()) ?? 0) > 0;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final employeeId = _selectedEmployee!.id;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final date = Fmt.dateApi(_date);
    final notes = _notesCtrl.text.trim();

    try {
      await PayrollService.createAdvance(
        employeeId,
        amount: amount,
        advanceDate: date,
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adelanto registrado correctamente'),
          backgroundColor: AppColors.successFg,
        ),
      );
      context.pop(true);
    } on DioException catch (e) {
      debugPrint(
        '[RegisterAdvanceScreen] POST advance error status=${e.response?.statusCode} '
        'body=${e.response?.data}',
      );
      if (!mounted) return;
      setState(() {
        _error = _extractError(e);
        _saving = false;
      });
    } catch (e) {
      debugPrint('[RegisterAdvanceScreen] POST advance unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo registrar el adelanto. Intenta de nuevo.';
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
    return 'No se pudo registrar el adelanto. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  if (_error != null) ...[
                    AppCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.errorFg,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.errorFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Employee selector (only when not pre-filled)
                  if (widget.employee == null) ...[
                    SectionHeader(title: 'Trabajador'),
                    const SizedBox(height: 10),
                    AppCard(child: _buildEmployeeSelector()),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Pre-filled employee banner
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(18),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text(
                                widget.employee!.firstName.isNotEmpty
                                    ? widget.employee!.firstName[0]
                                          .toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.employee!.fullName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (widget.employee!.currentSalary != null)
                                  Text(
                                    'Sueldo: ${Fmt.lempira(widget.employee!.currentSalary!.salary)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SectionHeader(title: 'Datos del adelanto'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      children: [
                        AppTextField(
                          label: 'MONTO (L)',
                          hint: 'Ej: 500.00',
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FECHA DEL ADELANTO',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
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
                                    Text(
                                      Fmt.dateFull(_date),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'NOTAS (OPCIONAL)',
                          hint: 'Ej: Para pago de emergencia',
                          controller: _notesCtrl,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Registrar adelanto',
                    onPressed: _canSave ? _save : null,
                    loading: _saving,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSelector() {
    if (_loadingEmployees) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_employeeLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.errorFg,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _employeeLoadError!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.errorFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Reintentar',
            onPressed: _loadEmployees,
            icon: Icons.refresh_rounded,
            size: AppButtonSize.sm,
            fullWidth: false,
          ),
        ],
      );
    }

    if (_employees.isEmpty) {
      return Text(
        'No hay trabajadores activos para registrar adelantos.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textMuted,
          height: 1.4,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECCIONAR TRABAJADOR',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButton<Employee>(
          value: _selectedEmployee,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          hint: Text(
            'Elige un trabajador',
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted),
          ),
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
          onChanged: (e) => setState(() {
            _selectedEmployee = e;
          }),
        ),
      ],
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
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  'Registrar adelanto',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
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
}
