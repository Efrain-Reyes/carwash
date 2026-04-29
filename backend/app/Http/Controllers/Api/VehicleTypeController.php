<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\VehicleType;
use Illuminate\Http\JsonResponse;

class VehicleTypeController extends Controller
{
    public function index(): JsonResponse
    {
        $types = VehicleType::with(['washServices' => function ($query) {
            $query->where('is_active', true)->orderBy('id');
        }])
            ->where('is_active', true)
            ->orderBy('id')
            ->get();

        return response()->json($types);
    }

    public function toggle(VehicleType $vehicleType): JsonResponse
    {
        $vehicleType->update(['is_active' => ! $vehicleType->is_active]);

        return response()->json($vehicleType);
    }
}
