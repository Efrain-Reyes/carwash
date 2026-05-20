import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

enum NavTab { home, lavados, gastos, nomina, cajas, reportes }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current, required this.onTap});

  final NavTab current;
  final ValueChanged<NavTab> onTap;

  static const _items = [
    (
      tab: NavTab.home,
      label: 'Inicio',
      icon: Icons.home_rounded,
      iconOutlined: Icons.home_outlined,
    ),
    (
      tab: NavTab.lavados,
      label: 'Lavados',
      icon: Icons.local_car_wash_rounded,
      iconOutlined: Icons.local_car_wash_outlined,
    ),
    (
      tab: NavTab.gastos,
      label: 'Gastos',
      icon: Icons.receipt_rounded,
      iconOutlined: Icons.receipt_outlined,
    ),
    (
      tab: NavTab.nomina,
      label: 'Nómina',
      icon: Icons.group_rounded,
      iconOutlined: Icons.group_outlined,
    ),
    (
      tab: NavTab.cajas,
      label: 'Cajas',
      icon: Icons.point_of_sale_rounded,
      iconOutlined: Icons.point_of_sale_outlined,
    ),
    (
      tab: NavTab.reportes,
      label: 'Reportes',
      icon: Icons.bar_chart_rounded,
      iconOutlined: Icons.bar_chart_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xEEFFFFFF),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: _items.map((item) {
              final active = current == item.tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(item.tab),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 50,
                        height: 28,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary.withAlpha(26)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          active ? item.icon : item.iconOutlined,
                          size: 20,
                          color: active
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : AppColors.textMuted,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
