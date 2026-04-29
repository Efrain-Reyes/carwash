<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WashService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WashServiceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = WashService::with('vehicleType')
            ->where('is_active', true)
            ->orderBy('vehicle_type_id')
            ->orderBy('id');

        if ($request->filled('vehicle_type_id')) {
            $query->where('vehicle_type_id', $request->vehicle_type_id);
        }

        return response()->json($query->get());
    }

    public function update(Request $request, WashService $washService): JsonResponse
    {
        $data = $request->validate([
            'name'       => 'sometimes|string|max:100',
            'base_price' => 'sometimes|nullable|numeric|min:0',
        ]);

        $washService->update($data);

        return response()->json($washService);
    }

    public function toggle(WashService $washService): JsonResponse
    {
        $washService->update(['is_active' => ! $washService->is_active]);

        return response()->json($washService);
    }
}
