import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../../washes/models/vehicle_type.dart';
import '../services/catalog_service.dart';

class RegisterWashServiceScreen extends StatefulWidget {
  const RegisterWashServiceScreen({super.key, this.vehicleType});

  final VehicleType? vehicleType;

  @override
  State<RegisterWashServiceScreen> createState() =>
      _RegisterWashServiceScreenState();
}

class _RegisterWashServiceScreenState
    extends State<RegisterWashServiceScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<VehicleType> _vehicleTypes = [];
  VehicleType? _selectedVehicleType;
  bool _isCustom = false;
  bool _loadingVehicleTypes = false;
  bool _saving = false;
  String? _error;
  String? _vehicleTypeLoadError;

  @override
  void initState() {
    super.initState();
    if (widget.vehicleType != null) {
      _selectedVehicleType = widget.vehicleType;
    } else {
      _loadVehicleTypes();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleTypes() async {
    setState(() {
      _loadingVehicleTypes = true;
      _vehicleTypeLoadError = null;
    });
    try {
      final list = await CatalogService.getVehicleTypes();
      if (!mounted) return;
      setState(() {
        _vehicleTypes = list.where((v) => v.isActive).toList();
        _loadingVehicleTypes = false;
      });
    } catch (e) {
      debugPrint(
        '[RegisterWashServiceScreen] Error loading vehicle types: $e',
      );
      if (!mounted) return;
      setState(() {
        _vehicleTypeLoadError = 'No se pudo cargar los tipos de vehículo.';
        _loadingVehicleTypes = false;
      });
    }
  }

  bool get _canSave {
    if (_saving) return false;
    if (_selectedVehicleType == null) return false;
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (!_isCustom) {
      final price = double.tryParse(_priceCtrl.text.trim());
      if (price == null || price <= 0) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final vehicleTypeId = _selectedVehicleType!.id;
    final name = _nameCtrl.text.trim();
    final price = _isCustom ? null : double.tryParse(_priceCtrl.text.trim());

    try {
      await CatalogService.createWashService(
        vehicleTypeId: vehicleTypeId,
        name: name,
        isCustom: _isCustom,
        basePrice: price,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio creado correctamente'),
          backgroundColor: AppColors.successFg,
        ),
      );
      context.pop(true);
    } on DioException catch (e) {
      debugPrint(
        '[RegisterWashServiceScreen] POST wash-services error '
        'status=${e.response?.statusCode} body=${e.response?.data}',
      );
      if (!mounted) return;
      setState(() {
        _error = _extractError(e);
        _saving = false;
      });
    } catch (e) {
      debugPrint(
        '[RegisterWashServiceScreen] POST wash-services unexpected error: $e',
      );
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo crear el servicio. Intenta de nuevo.';
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
    return 'No se pudo crear el servicio. Intenta de nuevo.';
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

                  if (widget.vehicleType == null) ...[
                    SectionHeader(title: 'Tipo de vehículo'),
                    const SizedBox(height: 10),
                    AppCard(child: _buildVehicleTypeSelector()),
                    const SizedBox(height: 16),
                  ] else ...[
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
                            child: const Center(
                              child: Icon(
                                Icons.directions_car_filled_rounded,
                                color: AppColors.accent,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.vehicleType!.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SectionHeader(title: 'Datos del servicio'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      children: [
                        AppTextField(
                          label: 'NOMBRE',
                          hint: 'Ej: Lavado básico',
                          controller: _nameCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isCustom,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) => setState(() => _isCustom = v),
                          title: Text(
                            '¿Servicio personalizado?',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'El precio se captura manualmente al registrar el lavado',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (!_isCustom) ...[
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'PRECIO BASE (L)',
                            hint: 'Ej: 250.00',
                            controller: _priceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
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

  Widget _buildVehicleTypeSelector() {
    if (_loadingVehicleTypes) {
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

    if (_vehicleTypeLoadError != null) {
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
                  _vehicleTypeLoadError!,
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
            onPressed: _loadVehicleTypes,
            icon: Icons.refresh_rounded,
            size: AppButtonSize.sm,
            fullWidth: false,
          ),
        ],
      );
    }

    if (_vehicleTypes.isEmpty) {
      return Text(
        'No hay tipos de vehículo activos. Crea uno primero.',
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
          'SELECCIONAR TIPO DE VEHÍCULO',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButton<VehicleType>(
          value: _selectedVehicleType,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          hint: Text(
            'Elige un tipo de vehículo',
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted),
          ),
          items: _vehicleTypes
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(
                    v.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _selectedVehicleType = v;
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
                  'Nuevo servicio',
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
