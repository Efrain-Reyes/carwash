import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cash_session_model.dart';
import '../services/cash_sessions_service.dart';

class CashSessionsScreen extends StatefulWidget {
  const CashSessionsScreen({super.key});

  @override
  State<CashSessionsScreen> createState() => _CashSessionsScreenState();
}

class _CashSessionsScreenState extends State<CashSessionsScreen> {
  List<CashSessionModel> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    if (!isAdmin) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessions = await CashSessionsService.getCashSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _parseError(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el historial de cajas.';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(CashSessionModel session) async {
    try {
      final detail = await CashSessionsService.getCashSession(session.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) => _CashSessionDetailSheet(
          session: detail,
          onEdit: () {
            Navigator.of(sheetContext).pop();
            _showEditDialog(detail);
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el detalle.')),
      );
    }
  }

  Future<void> _showEditDialog(CashSessionModel session) async {
    final countedController = TextEditingController(
      text: session.countedClosingAmount?.toStringAsFixed(2) ?? '',
    );
    final notesController = TextEditingController(text: session.notes ?? '');
    final reasonController = TextEditingController();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    var submitting = false;
    var countedText = countedController.text;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final counted = _parseAmount(countedText);
            final expected = session.expectedClosingAmount ?? 0;
            final difference = counted == null ? null : counted - expected;

            Future<void> submit() async {
              final amount = _parseAmount(countedController.text);
              if (amount == null) {
                setDialogState(() => error = 'Ingresa un monto válido.');
                return;
              }
              if (reasonController.text.trim().isEmpty) {
                setDialogState(() => error = 'Ingresa el motivo del ajuste.');
                return;
              }

              setDialogState(() {
                submitting = true;
                error = null;
              });

              try {
                final result = await CashSessionsService.adjustClosing(
                  id: session.id,
                  countedClosingAmount: amount,
                  notes: notesController.text,
                  reason: reasonController.text,
                );
                if (!mounted) return;

                navigator.pop();
                final warning = result.warning;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      warning == null || warning.isEmpty
                          ? 'Cierre actualizado.'
                          : warning,
                    ),
                  ),
                );
                await _load();
              } on DioException catch (e) {
                setDialogState(() {
                  submitting = false;
                  error = _parseError(e);
                });
              } catch (_) {
                setDialogState(() {
                  submitting = false;
                  error = 'No se pudo guardar el ajuste.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Editar cierre de caja'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CashHelpText(),
                    const SizedBox(height: 12),
                    _MiniSummaryRow(
                      label: 'Dinero esperado en caja',
                      value: Fmt.lempira(expected),
                    ),
                    if (difference != null) ...[
                      const SizedBox(height: 8),
                      _DifferencePreview(difference: difference),
                    ],
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Efectivo total contado en caja',
                      hint: 'Ej. 1500.00',
                      controller: countedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => countedText = value),
                    ),
                    const SizedBox(height: 6),
                    _InputHelp(),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Notas',
                      hint: 'Opcional',
                      controller: notesController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Motivo del ajuste',
                      hint: 'Explica por qué se corrige el cierre',
                      controller: reasonController,
                      maxLines: 3,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.errorFg,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                AppButton(
                  label: 'Guardar',
                  onPressed: submitting ? null : submit,
                  fullWidth: false,
                  size: AppButtonSize.sm,
                  loading: submitting,
                ),
              ],
            );
          },
        );
      },
    );

    countedController.dispose();
    notesController.dispose();
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CashHeader(),
          Expanded(
            child: !isAdmin ? const _OperatorNotice() : _buildAdminBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null) {
      return _CashError(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CashHelpCard(),
            const SizedBox(height: 16),
            SectionHeader(title: 'Historial de cajas'),
            const SizedBox(height: 10),
            if (_sessions.isEmpty)
              const _EmptyCashHistory()
            else
              for (final session in _sessions) ...[
                _CashSessionCard(
                  session: session,
                  onTap: () => _openDetail(session),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'No se pudo conectar con el servidor.';
  }
}

class _CashHeader extends StatelessWidget {
  const _CashHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Text(
            'Cajas',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CashHelpCard extends StatelessWidget {
  const _CashHelpCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(child: _CashHelpText());
  }
}

class _CashHelpText extends StatelessWidget {
  const _CashHelpText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Efectivo total contado en caja es todo el dinero físico al cierre: saldo inicial más ingresos, menos gastos, adelantos y nómina.',
      style: GoogleFonts.inter(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _CashSessionCard extends StatelessWidget {
  const _CashSessionCard({required this.session, required this.onTap});

  final CashSessionModel session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final difference = session.difference;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _sessionTitle(session),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusPill(session: session),
            ],
          ),
          const SizedBox(height: 10),
          _MiniSummaryRow(
            label: 'Dinero esperado en caja',
            value: session.expectedClosingAmount == null
                ? 'Pendiente'
                : Fmt.lempira(session.expectedClosingAmount!),
          ),
          _MiniSummaryRow(
            label: 'Efectivo total contado en caja',
            value: session.countedClosingAmount == null
                ? 'Pendiente'
                : Fmt.lempira(session.countedClosingAmount!),
          ),
          if (difference != null)
            _MiniSummaryRow(
              label: _differenceTitle(difference),
              value: Fmt.lempira(difference),
              valueColor: _differenceColor(difference),
            ),
          if (session.needsReview) ...[
            const SizedBox(height: 8),
            _ReviewWarning(),
          ],
        ],
      ),
    );
  }
}

class _CashSessionDetailSheet extends StatelessWidget {
  const _CashSessionDetailSheet({required this.session, required this.onEdit});

  final CashSessionModel session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _sessionTitle(session),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusPill(session: session),
              ],
            ),
            const SizedBox(height: 14),
            _CashHelpText(),
            const SizedBox(height: 14),
            _MiniSummaryRow(
              label: 'Saldo inicial',
              value: Fmt.lempira(session.openingAmount),
            ),
            _MiniSummaryRow(
              label: 'Dinero esperado en caja',
              value: session.expectedClosingAmount == null
                  ? 'Pendiente'
                  : Fmt.lempira(session.expectedClosingAmount!),
            ),
            _MiniSummaryRow(
              label: 'Efectivo total contado en caja',
              value: session.countedClosingAmount == null
                  ? 'Pendiente'
                  : Fmt.lempira(session.countedClosingAmount!),
            ),
            if (session.difference != null)
              _MiniSummaryRow(
                label: _differenceTitle(session.difference!),
                value: Fmt.lempira(session.difference!),
                valueColor: _differenceColor(session.difference!),
              ),
            if ((session.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                session.notes!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (session.needsReview) ...[
              const SizedBox(height: 12),
              _ReviewWarning(),
            ],
            if (session.isClosed) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Editar cierre',
                onPressed: onEdit,
                icon: Icons.edit_rounded,
                size: AppButtonSize.sm,
              ),
            ],
            const SizedBox(height: 18),
            SectionHeader(title: 'Auditoría'),
            const SizedBox(height: 10),
            if (session.adjustments.isEmpty)
              Text(
                'Sin ajustes registrados.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              )
            else
              for (final adjustment in session.adjustments) ...[
                _AdjustmentRow(adjustment: adjustment),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({required this.adjustment});

  final CashSessionAdjustmentModel adjustment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            adjustment.reason,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          _MiniSummaryRow(
            label: 'Antes',
            value: adjustment.oldCountedClosingAmount == null
                ? 'Sin conteo'
                : Fmt.lempira(adjustment.oldCountedClosingAmount!),
          ),
          _MiniSummaryRow(
            label: 'Después',
            value: Fmt.lempira(adjustment.newCountedClosingAmount),
          ),
          Text(
            [
              if (adjustment.user?.name.isNotEmpty == true)
                adjustment.user!.name,
              if (adjustment.createdAt != null)
                _dateTimeLabel(adjustment.createdAt!),
            ].join(' · '),
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.session});

  final CashSessionModel session;

  @override
  Widget build(BuildContext context) {
    final color = session.isOpen ? AppColors.successFg : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        session.isOpen ? 'Abierta' : 'Cerrada',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MiniSummaryRow extends StatelessWidget {
  const _MiniSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifferencePreview extends StatelessWidget {
  const _DifferencePreview({required this.difference});

  final double difference;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _differenceColor(difference).withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_differenceTitle(difference)}: ${Fmt.lempira(difference)}',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _differenceColor(difference),
        ),
      ),
    );
  }
}

class _InputHelp extends StatelessWidget {
  const _InputHelp();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Debe incluir el saldo inicial más ingresos, menos gastos, adelantos y nómina.',
      style: GoogleFonts.inter(
        fontSize: 11,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ReviewWarning extends StatelessWidget {
  const _ReviewWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Revisar: el efectivo total contado fue menor que el dinero esperado. Si se ingresó solo lo vendido del día, edite el cierre.',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.warningFg,
        ),
      ),
    );
  }
}

class _OperatorNotice extends StatelessWidget {
  const _OperatorNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'El historial y los ajustes de caja están disponibles solo para administradores.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CashError extends StatelessWidget {
  const _CashError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            AppButtonSecondary(
              label: 'Reintentar',
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCashHistory extends StatelessWidget {
  const _EmptyCashHistory();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Aún no hay cajas registradas.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

String _sessionTitle(CashSessionModel session) {
  final opened = session.openedAt;
  if (opened == null) return 'Caja #${session.id}';
  return 'Caja ${Fmt.dateFull(opened)}';
}

String _dateTimeLabel(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '${Fmt.dateFull(date)} $h:$m';
}

double? _parseAmount(String value) {
  final amount = double.tryParse(value.trim().replaceAll(',', '.'));
  if (amount == null || amount < 0) return null;
  return amount;
}

String _differenceTitle(double difference) {
  if (difference < 0) return 'Faltante de caja';
  if (difference > 0) return 'Sobrante de caja';
  return 'Caja cuadrada';
}

Color _differenceColor(double difference) {
  if (difference < 0) return AppColors.errorFg;
  if (difference > 0) return AppColors.warningFg;
  return AppColors.successFg;
}
