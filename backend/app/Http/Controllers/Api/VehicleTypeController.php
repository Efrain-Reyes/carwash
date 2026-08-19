<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\VehicleType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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
                $query->where('is_active', true);
            }
            $query->orderBy('id');
        }])
            ->when(! $showAll, fn ($query) => $query->where('is_active', true))
            ->orderBy('id')
            ->get();

        return response()->json($types);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
        ]);

        $vehicleType = VehicleType::create([
            ...$data,
            'is_active' => true,
        ]);

        return response()->json($vehicleType, 201);
    }

    public function toggle(VehicleType $vehicleType): JsonResponse
    {
        $vehicleType->update(['is_active' => ! $vehicleType->is_active]);

        return response()->json($vehicleType);
    }
}
