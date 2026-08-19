import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../services/catalog_service.dart';

class RegisterVehicleTypeScreen extends StatefulWidget {
  const RegisterVehicleTypeScreen({super.key});

  @override
  State<RegisterVehicleTypeScreen> createState() =>
      _RegisterVehicleTypeScreenState();
}

class _RegisterVehicleTypeScreenState
    extends State<RegisterVehicleTypeScreen> {
  final _nameCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => !_saving && _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await CatalogService.createVehicleType(_nameCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tipo de vehículo creado correctamente'),
          backgroundColor: AppColors.successFg,
        ),
      );
      context.pop(true);
    } on DioException catch (e) {
      debugPrint(
        '[RegisterVehicleTypeScreen] POST vehicle-types error '
        'status=${e.response?.statusCode} body=${e.response?.data}',
      );
      if (!mounted) return;
      setState(() {
        _error = _extractError(e);
        _saving = false;
      });
    } catch (e) {
      debugPrint(
        '[RegisterVehicleTypeScreen] POST vehicle-types unexpected error: $e',
      );
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo crear el tipo de vehículo. Intenta de nuevo.';
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
    return 'No se pudo crear el tipo de vehículo. Intenta de nuevo.';
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
                  SectionHeader(title: 'Datos del tipo de vehículo'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: AppTextField(
                      label: 'NOMBRE',
                      hint: 'Ej: Carro, Camioneta, Motocicleta',
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
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
                  'Nuevo tipo de vehículo',
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
