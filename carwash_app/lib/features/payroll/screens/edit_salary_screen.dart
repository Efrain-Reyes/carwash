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

class EditSalaryScreen extends StatefulWidget {
  const EditSalaryScreen({super.key, required this.employee});
  final Employee employee;

  @override
  State<EditSalaryScreen> createState() => _EditSalaryScreenState();
}

class _EditSalaryScreenState extends State<EditSalaryScreen> {
  final _salaryCtrl = TextEditingController();
  final _workDaysCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _effectiveFrom = DateTime.now();
  String _frequency = 'semanal';
  bool _saving = false;
  String? _error;

  static const _frequencies = [
    ('semanal', 'Semanal'),
    ('quincenal', 'Quincenal'),
    ('mensual', 'Mensual'),
  ];

  static const _defaultDays = {
    'semanal': '6',
    'quincenal': '12',
    'mensual': '26',
  };

  @override
  void initState() {
    super.initState();
    final salary = widget.employee.currentSalary;
    if (salary != null) {
      _salaryCtrl.text = salary.salary.toStringAsFixed(2);
      _frequency = _normalizeFrequency(salary.paymentFrequency);
      _workDaysCtrl.text = salary.workDaysPerPeriod.toString();
    } else {
      _workDaysCtrl.text = _defaultDays[_frequency]!;
    }
  }

  String _normalizeFrequency(String value) {
    final known = _frequencies.map((f) => f.$1).toSet();
    return known.contains(value) ? value : 'semanal';
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    _workDaysCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      (double.tryParse(_salaryCtrl.text.trim()) ?? 0) > 0 &&
      (int.tryParse(_workDaysCtrl.text.trim()) ?? 0) > 0;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _effectiveFrom = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final notes = _notesCtrl.text.trim();

    try {
      await PayrollService.updateSalary(
        employeeId: widget.employee.id,
        salary: double.parse(_salaryCtrl.text.trim()),
        paymentFrequency: _frequency,
        workDaysPerPeriod: int.parse(_workDaysCtrl.text.trim()),
        effectiveFrom: Fmt.dateApi(_effectiveFrom),
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sueldo actualizado correctamente'),
          backgroundColor: AppColors.successFg,
        ),
      );
      context.pop(true);
    } on DioException catch (e) {
      debugPrint(
        '[EditSalaryScreen] POST salary error status=${e.response?.statusCode} '
        'body=${e.response?.data}',
      );
      if (!mounted) return;
      setState(() {
        _error = _extractError(e);
        _saving = false;
      });
    } catch (e) {
      debugPrint('[EditSalaryScreen] POST salary unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo actualizar el sueldo. Intenta de nuevo.';
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
    return 'No se pudo actualizar el sueldo. Intenta de nuevo.';
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

                  SectionHeader(title: 'Nuevo sueldo'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      children: [
                        AppTextField(
                          label: 'SALARIO (L)',
                          hint: 'Ej: 1800.00',
                          controller: _salaryCtrl,
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
                              'FRECUENCIA DE PAGO',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: _frequencies.map((pair) {
                                final (value, label) = pair;
                                final selected = _frequency == value;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _frequency = value;
                                      _workDaysCtrl.text = _defaultDays[value]!;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.surface2,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        label,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'DÍAS POR PERIODO',
                          hint: 'Ej: 6',
                          controller: _workDaysCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VIGENTE DESDE',
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
                                      Fmt.dateFull(_effectiveFrom),
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
                          hint: 'Ej: Ajuste por desempeño',
                          controller: _notesCtrl,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Guardar',
                    onPressed: _canSave ? _save : null,
                    loading: _saving,
                    icon: Icons.save_rounded,
                  ),
                ],
              ),
            ),
          ),
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
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  'Editar sueldo',
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
