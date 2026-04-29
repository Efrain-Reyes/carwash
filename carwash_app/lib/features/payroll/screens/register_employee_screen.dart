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
import '../services/payroll_service.dart';

class RegisterEmployeeScreen extends StatefulWidget {
  const RegisterEmployeeScreen({super.key});

  @override
  State<RegisterEmployeeScreen> createState() => _RegisterEmployeeScreenState();
}

class _RegisterEmployeeScreenState extends State<RegisterEmployeeScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _workDaysCtrl = TextEditingController();

  DateTime _hireDate = DateTime.now();
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
    _workDaysCtrl.text = _defaultDays[_frequency]!;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _salaryCtrl.dispose();
    _workDaysCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_salaryCtrl.text.trim()) ?? 0) > 0 &&
      (int.tryParse(_workDaysCtrl.text.trim()) ?? 0) > 0;

  Future<void> _pickDate(bool isHire) async {
    final now = DateTime.now();
    final initial = isHire ? _hireDate : _effectiveFrom;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isHire) {
        _hireDate = picked;
      } else {
        _effectiveFrom = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await PayrollService.createEmployee(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        hireDate: Fmt.dateApi(_hireDate),
        salary: double.parse(_salaryCtrl.text.trim()),
        paymentFrequency: _frequency,
        workDaysPerPeriod: int.parse(_workDaysCtrl.text.trim()),
        effectiveFrom: Fmt.dateApi(_effectiveFrom),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trabajador registrado correctamente'),
          backgroundColor: AppColors.successFg,
        ),
      );
      context.pop(true);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response!.data['message']?.toString()
          : null;
      setState(() {
        _error = msg ?? 'No se pudo registrar el trabajador. Intenta de nuevo.';
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo registrar el trabajador. Intenta de nuevo.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
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

                  SectionHeader(title: 'Datos personales'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      children: [
                        AppTextField(
                          label: 'NOMBRE',
                          hint: 'Ej: Juan',
                          controller: _firstNameCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'APELLIDO',
                          hint: 'Ej: Pérez',
                          controller: _lastNameCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'TELÉFONO (OPCIONAL)',
                          hint: 'Ej: 9999-8888',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _DateField(
                          label: 'FECHA DE CONTRATACIÓN',
                          date: _hireDate,
                          onTap: () => _pickDate(true),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SectionHeader(title: 'Salario inicial'),
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
                        _DateField(
                          label: 'VIGENTE DESDE',
                          date: _effectiveFrom,
                          onTap: () => _pickDate(false),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Registrar trabajador',
                    onPressed: _canSave ? _save : null,
                    loading: _saving,
                    icon: Icons.person_add_rounded,
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
              Text(
                'Nuevo trabajador',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Date field ───────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  Fmt.dateFull(date),
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
    );
  }
}
