<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WashService;
use App\Models\WashServiceType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Cada WashService es el precio de un servicio del catálogo para un tipo de vehículo.
 * Estos endpoints mantienen el formato que ya usa la app; el panel web administra
 * el catálogo completo (Admin\WashServiceController).
 */
class WashServiceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $showAll = $request->boolean('include_inactive') && ($request->user()?->can('catalog.manage') ?? false);

        $query = WashService::with('vehicleType')
            ->when(! $showAll, fn ($q) => $q->where('is_active', true)
                ->whereHas('serviceType', fn ($q) => $q->where('is_active', true)))
            ->orderBy('vehicle_type_id')
            ->orderBy('id');

        if ($request->filled('vehicle_type_id')) {
            $query->where('vehicle_type_id', $request->vehicle_type_id);
        }

        return response()->json($query->get());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'vehicle_type_id' => 'required|integer|exists:vehicle_types,id',
            'name'            => 'required|string|max:100',
            'is_custom'       => 'boolean',
            'base_price'      => ['required_if:is_custom,false', 'nullable', 'numeric', 'min:0'],
        ]);

        $washService = DB::transaction(function () use ($data) {
            // Si el servicio ya existe en el catálogo (mismo nombre) se reutiliza.
            $type = WashServiceType::findOrCreateByName($data['name'], $data['is_custom'] ?? false);

            if ($type->prices()->where('vehicle_type_id', $data['vehicle_type_id'])->exists()) {
                throw ValidationException::withMessages([
                    'name' => 'Ese servicio ya existe para este tipo de vehículo.',
                ]);
            }

            return WashService::create([
                'wash_service_type_id' => $type->id,
                'vehicle_type_id'      => $data['vehicle_type_id'],
                'name'                 => $type->name,
                'is_custom'            => $type->is_custom,
                'base_price'           => $type->is_custom ? null : ($data['base_price'] ?? null),
                'is_active'            => true,
            ]);
        });

        return response()->json($washService->load('vehicleType'), 201);
    }

    public function update(Request $request, WashService $washService): JsonResponse
    {
        $data = $request->validate([
            'name'       => 'sometimes|string|max:100',
            'base_price' => 'sometimes|nullable|numeric|min:0',
        ]);

        // El nombre es del servicio del catálogo: cambiarlo lo cambia para todos los vehículos.
        if (isset($data['name']) && $washService->serviceType) {
            $name = trim($data['name']);
            $taken = WashServiceType::whereRaw('LOWER(name) = ?', [mb_strtolower($name)])
                ->whereKeyNot($washService->wash_service_type_id)
                ->exists();

            if ($taken) {
                throw ValidationException::withMessages(['name' => 'Ya existe otro servicio con ese nombre.']);
            }

            $washService->serviceType->update(['name' => $name]);
            unset($data['name']);
        }

        $washService->refresh()->update($data);

        return response()->json($washService);
    }

    public function toggle(WashService $washService): JsonResponse
    {
        $washService->update(['is_active' => ! $washService->is_active]);

        return response()->json($washService);
    }
}
