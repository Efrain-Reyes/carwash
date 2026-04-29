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
import '../../../shared/widgets/status_badge.dart';
import '../models/advance_model.dart';
import '../services/payroll_service.dart';

AdvanceStatus _toAdvanceStatus(String s) => switch (s) {
  'pendiente' => AdvanceStatus.pendiente,
  'parcialmente_pagado' => AdvanceStatus.parcialmentePagado,
  'pagado' => AdvanceStatus.pagado,
  _ => AdvanceStatus.anulado,
};

class AdvanceDetailScreen extends StatefulWidget {
  const AdvanceDetailScreen({
    super.key,
    required this.advanceId,
    this.initialAdvance,
  });

  final int advanceId;
  final Advance? initialAdvance;

  @override
  State<AdvanceDetailScreen> createState() => _AdvanceDetailScreenState();
}

class _AdvanceDetailScreenState extends State<AdvanceDetailScreen> {
  Advance? _advance;
  bool _loading = true;
  String? _error;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _advance = widget.initialAdvance;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final advance = await PayrollService.getAdvance(widget.advanceId);
      if (!mounted) return;
      setState(() {
        _advance = advance;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AdvanceDetailScreen] Error loading advance: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cargar el detalle del adelanto.\nVerifica tu red e intenta de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _openPaymentSheet() async {
    final advance = _advance;
    if (advance == null || advance.isPaid) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdvancePaymentSheet(advance: advance),
    );

    if ((saved ?? false) && mounted) {
      _didChange = true;
      await _load();
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
    final name = _advance?.employeeName;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de adelanto',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (name != null && name.isNotEmpty)
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _advance == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null && _advance == null) {
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

    final advance = _advance;
    if (advance == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _SummaryCard(advance: advance),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.accent,
              backgroundColor: AppColors.border,
            ),
          ],
          const SizedBox(height: 16),
          if (advance.isPaid)
            AppCard(
              child: Text(
                'Este adelanto ya fue pagado',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successFg,
                ),
              ),
            )
          else if (advance.isPending || advance.isPartial)
            AppButton(
              label: 'Registrar abono',
              onPressed: _openPaymentSheet,
              icon: Icons.payments_rounded,
            ),
          const SizedBox(height: 18),
          SectionHeader(title: 'Pagos realizados'),
          const SizedBox(height: 10),
          if (advance.payments.isEmpty)
            AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Sin pagos registrados',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            )
          else
            ...advance.payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PaymentCard(payment: payment),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.advance});

  final Advance advance;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advance.employeeName.isNotEmpty
                          ? advance.employeeName
                          : 'Empleado #${advance.employeeId}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fecha: ${Fmt.dateShort(advance.advanceDate)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge.advance(_toAdvanceStatus(advance.status)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AmountBlock(
                  label: 'Monto original',
                  value: Fmt.lempira(advance.amount),
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AmountBlock(
                  label: 'Saldo pendiente',
                  value: Fmt.lempira(advance.balance),
                  color: advance.isPaid
                      ? AppColors.successFg
                      : AppColors.warningFg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: advance.progress,
              minHeight: 7,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                advance.isPaid ? AppColors.successFg : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(advance.progress * 100).round()}% pagado',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          if (advance.notes != null && advance.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 16,
                  color: AppColors.textMuted2,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    advance.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.35,
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

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.label,
    required this.value,
    required this.color,
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
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final AdvancePayment payment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.paymentTypeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                Fmt.lempira(payment.amount),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.successFg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            Fmt.dateShort(payment.paymentDate),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          if (payment.registeredByName != null) ...[
            const SizedBox(height: 3),
            Text(
              'Registrado por ${payment.registeredByName}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (payment.notes != null && payment.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payment.notes!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdvancePaymentSheet extends StatefulWidget {
  const _AdvancePaymentSheet({required this.advance});

  final Advance advance;

  @override
  State<_AdvancePaymentSheet> createState() => _AdvancePaymentSheetState();
}

class _AdvancePaymentSheetState extends State<_AdvancePaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  bool get _canSave =>
      !_saving && _amount > 0 && _amount <= widget.advance.balance;

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

  Future<void> _save() async {
    if (_amount <= 0) {
      setState(() => _error = 'El monto debe ser mayor a cero.');
      return;
    }
    if (_amount > widget.advance.balance) {
      setState(
        () => _error =
            'El abono no puede ser mayor al saldo pendiente (${Fmt.lempira(widget.advance.balance)}).',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await PayrollService.createAdvancePayment(
        advanceId: widget.advance.id,
        amount: _amount,
        paymentDate: Fmt.dateApi(_date),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _extractError(e);
        _saving = false;
      });
    } catch (e) {
      debugPrint('[AdvancePaymentSheet] Unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo registrar el abono. Intenta de nuevo.';
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
    return 'No se pudo registrar el abono. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Registrar abono',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => context.pop(false),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                Text(
                  'Saldo pendiente: ${Fmt.lempira(widget.advance.balance)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningFg,
                  ),
                ),
                const SizedBox(height: 14),
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
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 14),
                      _DateField(date: _date, onTap: _pickDate),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'NOTAS (OPCIONAL)',
                        hint: 'Ej: Abonó en efectivo',
                        controller: _notesCtrl,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Guardar abono',
                  onPressed: _canSave ? _save : null,
                  loading: _saving,
                  icon: Icons.payments_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FECHA DEL ABONO',
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
