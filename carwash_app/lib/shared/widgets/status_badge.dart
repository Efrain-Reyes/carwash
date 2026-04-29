import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

enum WashStatus { completado, anulado }
enum AdvanceStatus { pendiente, parcialmentePagado, pagado, anulado }

class StatusBadge extends StatelessWidget {
  const StatusBadge.wash(WashStatus status, {super.key})
      : _label = status == WashStatus.completado ? 'completado' : 'anulado',
        _bg = status == WashStatus.completado ? AppColors.successBg : AppColors.errorBg,
        _fg = status == WashStatus.completado ? AppColors.successFg : AppColors.errorFg,
        _dot = status == WashStatus.completado ? AppColors.successDot : AppColors.errorDot;

  const StatusBadge.advance(AdvanceStatus status, {super.key})
      : _label = status == AdvanceStatus.pendiente
            ? 'pendiente'
            : status == AdvanceStatus.parcialmentePagado
                ? 'parcial'
                : status == AdvanceStatus.pagado
                    ? 'pagado'
                    : 'anulado',
        _bg = status == AdvanceStatus.pendiente
            ? AppColors.warningBg
            : status == AdvanceStatus.parcialmentePagado
                ? AppColors.infoBg
                : status == AdvanceStatus.pagado
                    ? AppColors.successBg
                    : AppColors.errorBg,
        _fg = status == AdvanceStatus.pendiente
            ? AppColors.warningFg
            : status == AdvanceStatus.parcialmentePagado
                ? AppColors.infoFg
                : status == AdvanceStatus.pagado
                    ? AppColors.successFg
                    : AppColors.errorFg,
        _dot = status == AdvanceStatus.pendiente
            ? AppColors.warningDot
            : status == AdvanceStatus.parcialmentePagado
                ? AppColors.infoDot
                : status == AdvanceStatus.pagado
                    ? AppColors.successDot
                    : AppColors.errorDot;

  const StatusBadge.raw({
    super.key,
    required String label,
    required Color bg,
    required Color fg,
    required Color dot,
  })  : _label = label,
        _bg = bg,
        _fg = fg,
        _dot = dot;

  final String _label;
  final Color _bg;
  final Color _fg;
  final Color _dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _dot,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
