import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'app_card.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = AppColors.accent,
    this.delta,
    this.deltaPositive,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? delta;
  final bool? deltaPositive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = compact ? 12.0 : 16.0;
    final iconSize = compact ? 26.0 : 30.0;
    final valueSize = compact ? 19.0 : 26.0;

    return AppCard(
      padding: EdgeInsets.all(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: compact ? 14 : 16, color: iconColor),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  (deltaPositive ?? true)
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 11,
                  color: (deltaPositive ?? true)
                      ? AppColors.successFg
                      : AppColors.errorFg,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: (deltaPositive ?? true)
                        ? AppColors.successFg
                        : AppColors.errorFg,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'vs ayer',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
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
