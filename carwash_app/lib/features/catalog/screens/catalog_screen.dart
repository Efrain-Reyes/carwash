import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../washes/models/vehicle_type.dart';
import '../../washes/models/wash_service.dart';
import '../services/catalog_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<VehicleType> _vehicleTypes = [];
  bool _loading = true;
  String? _error;
  final Set<int> _togglingVehicleTypes = {};
  final Set<int> _togglingWashServices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    debugPrint('[CatalogScreen] Loading catalog...');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await CatalogService.getVehicleTypes(
        includeInactive: true,
      );
      debugPrint('[CatalogScreen] Vehicle types count: ${list.length}');
      if (!mounted) return;
      setState(() {
        _vehicleTypes = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[CatalogScreen] Error loading catalog: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cargar el catálogo.\nVerifica tu red e intenta de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _goToNewVehicleType() async {
    final created = await context.push<bool>(AppRouter.registerVehicleType);
    if ((created ?? false) && mounted) _load();
  }

  Future<void> _goToNewWashService([VehicleType? vehicleType]) async {
    final created = await context.push<bool>(
      AppRouter.registerWashService,
      extra: vehicleType,
    );
    if ((created ?? false) && mounted) _load();
  }

  Future<void> _toggleVehicleType(VehicleType vt) async {
    setState(() => _togglingVehicleTypes.add(vt.id));
    try {
      await CatalogService.toggleVehicleType(vt.id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      debugPrint('[CatalogScreen] Error toggling vehicle type: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el tipo de vehículo'),
          backgroundColor: AppColors.errorFg,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingVehicleTypes.remove(vt.id));
      }
    }
  }

  Future<void> _toggleWashService(WashService ws) async {
    setState(() => _togglingWashServices.add(ws.id));
    try {
      await CatalogService.toggleWashService(ws.id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      debugPrint('[CatalogScreen] Error toggling wash service: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el servicio'),
          backgroundColor: AppColors.errorFg,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingWashServices.remove(ws.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
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
                  'Catálogo de servicios',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _HeaderNewButton(
                onNewVehicleType: _goToNewVehicleType,
                onNewWashService: () => _goToNewWashService(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_error != null) {
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
    if (_vehicleTypes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.category_outlined,
              size: 44,
              color: AppColors.textMuted2,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay tipos de vehículo registrados',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Nuevo tipo de vehículo',
              onPressed: _goToNewVehicleType,
              icon: Icons.add_rounded,
              fullWidth: false,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        itemCount: _vehicleTypes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final vt = _vehicleTypes[i];
          return _VehicleTypeCard(
            vehicleType: vt,
            toggling: _togglingVehicleTypes.contains(vt.id),
            togglingWashServiceIds: _togglingWashServices,
            onToggle: () => _toggleVehicleType(vt),
            onToggleWashService: _toggleWashService,
            onAddWashService: () => _goToNewWashService(vt),
          );
        },
      ),
    );
  }
}

// ─── Vehicle type card ─────────────────────────────────────────────────────

class _VehicleTypeCard extends StatelessWidget {
  const _VehicleTypeCard({
    required this.vehicleType,
    required this.toggling,
    required this.togglingWashServiceIds,
    required this.onToggle,
    required this.onToggleWashService,
    required this.onAddWashService,
  });

  final VehicleType vehicleType;
  final bool toggling;
  final Set<int> togglingWashServiceIds;
  final VoidCallback onToggle;
  final ValueChanged<WashService> onToggleWashService;
  final VoidCallback onAddWashService;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  vehicleType.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.raw(
                label: vehicleType.isActive ? 'activo' : 'inactivo',
                bg: vehicleType.isActive
                    ? AppColors.successBg
                    : AppColors.errorBg,
                fg: vehicleType.isActive
                    ? AppColors.successFg
                    : AppColors.errorFg,
                dot: vehicleType.isActive
                    ? AppColors.successDot
                    : AppColors.errorDot,
              ),
              const SizedBox(width: 4),
              _ToggleButton(active: vehicleType.isActive, loading: toggling, onTap: onToggle),
            ],
          ),
          children: [
            if (vehicleType.washServices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No hay servicios registrados para este tipo de vehículo.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              ...vehicleType.washServices.map(
                (ws) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WashServiceRow(
                    washService: ws,
                    toggling: togglingWashServiceIds.contains(ws.id),
                    onToggle: () => onToggleWashService(ws),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddWashService,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Nuevo servicio',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WashServiceRow extends StatelessWidget {
  const _WashServiceRow({
    required this.washService,
    required this.toggling,
    required this.onToggle,
  });

  final WashService washService;
  final bool toggling;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final priceLabel = washService.isCustom
        ? 'Precio manual'
        : Fmt.lempira(washService.basePrice ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  washService.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  priceLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge.raw(
            label: washService.isActive ? 'activo' : 'inactivo',
            bg: washService.isActive
                ? AppColors.successBg
                : AppColors.errorBg,
            fg: washService.isActive
                ? AppColors.successFg
                : AppColors.errorFg,
            dot: washService.isActive
                ? AppColors.successDot
                : AppColors.errorDot,
          ),
          const SizedBox(width: 4),
          _ToggleButton(
            active: washService.isActive,
            loading: toggling,
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final bool active;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }
    return IconButton(
      onPressed: onTap,
      tooltip: active ? 'Desactivar' : 'Activar',
      visualDensity: VisualDensity.compact,
      icon: Icon(
        active
            ? Icons.toggle_on_rounded
            : Icons.toggle_off_outlined,
        color: active ? AppColors.successFg : AppColors.textMuted2,
        size: 26,
      ),
    );
  }
}

// ─── Header new button ─────────────────────────────────────────────────────

class _HeaderNewButton extends StatelessWidget {
  const _HeaderNewButton({
    required this.onNewVehicleType,
    required this.onNewWashService,
  });

  final VoidCallback onNewVehicleType;
  final VoidCallback onNewWashService;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Nuevo',
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (value) {
        if (value == 'vehicle_type') onNewVehicleType();
        if (value == 'wash_service') onNewWashService();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'vehicle_type',
          child: Row(
            children: [
              const Icon(
                Icons.directions_car_filled_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Text(
                'Nuevo tipo de vehículo',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'wash_service',
          child: Row(
            children: [
              const Icon(
                Icons.local_car_wash_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Text(
                'Nuevo servicio',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
