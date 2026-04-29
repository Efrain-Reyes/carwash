import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primarios
  static const primary     = Color(0xFF0B2545);
  static const primaryDeep = Color(0xFF091D38);
  static const accent      = Color(0xFF2EA8E0);

  // Fondos y superficies
  static const background = Color(0xFFF5F8FC);
  static const surface    = Color(0xFFFFFFFF);
  static const surface2   = Color(0xFFEEF2F7);
  static const border     = Color(0xFFE2E8EF);

  // Texto
  static const textPrimary = Color(0xFF0E1B2C);
  static const textMuted   = Color(0xFF6B7A8E);
  static const textMuted2  = Color(0xFFA8B3C2);

  // Estados — completado / pagado
  static const successBg  = Color(0xFFE5F5EC);
  static const successFg  = Color(0xFF0F7A4D);
  static const successDot = Color(0xFF1AAD6E);

  // Estados — anulado
  static const errorBg  = Color(0xFFFCE9E9);
  static const errorFg  = Color(0xFFB83C3C);
  static const errorDot = Color(0xFFD14747);
  static const error    = Color(0xFFD14747);

  // Estados — pendiente
  static const warningBg  = Color(0xFFFFF4DB);
  static const warningFg  = Color(0xFF8A5A00);
  static const warningDot = Color(0xFFE0A300);

  // Estados — parcialmente pagado
  static const infoBg  = Color(0xFFE2F1FB);
  static const infoFg  = Color(0xFF0E5C8A);
  static const infoDot = Color(0xFF2EA8E0);
}
