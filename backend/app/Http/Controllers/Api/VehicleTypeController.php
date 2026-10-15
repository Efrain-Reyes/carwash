<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\VehicleType;
use App\Models\WashServiceType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class VehicleTypeController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        // include_inactive=1 solo tiene efecto con permiso catalog.manage — lo usa
        // la pantalla de administración de catálogo para poder reactivar tipos
        // desactivados. El selector de vehículo al registrar un lavado no lo manda,
        // así que sigue viendo solo los activos como hasta ahora.
        $showAll = $request->boolean('include_inactive') && ($request->user()?->can('catalog.manage') ?? false);

        $types = VehicleType::with(['washServices' => function ($query) use ($showAll) {
            if (! $showAll) {
                // Un precio se ofrece si la fila está activa y el servicio del catálogo también.
                $query->where('is_active', true)
                    ->whereHas('serviceType', fn ($q) => $q->where('is_active', true));
            }
            $query->orderBy(
                WashServiceType::select('sort_order')->whereColumn('wash_service_types.id', 'wash_services.wash_service_type_id')
            )->orderBy('id');
        }])
            ->when(! $showAll, fn ($query) => $query->where('is_active', true))
            ->ordered()
            ->get();

        return response()->json($types);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
            'icon' => ['sometimes', Rule::in(array_keys(VehicleType::ICONS))],
        ]);

        $vehicleType = VehicleType::create([
            ...$data,
            'sort_order' => (int) VehicleType::max('sort_order') + 1,
            'is_active'  => true,
        ]);

        return response()->json($vehicleType->refresh(), 201);
    }

    public function toggle(VehicleType $vehicleType): JsonResponse
    {
        $vehicleType->update(['is_active' => ! $vehicleType->is_active]);

        return response()->json($vehicleType);
    }
}
