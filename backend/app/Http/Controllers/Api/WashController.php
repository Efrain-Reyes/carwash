<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreWashRequest;
use App\Models\Wash;
use App\Models\WashService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class WashController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tz = config('app.timezone');
        $user = $request->user();

        $query = Wash::with(['vehicleType', 'washService', 'user:id,name'])
            ->orderByDesc('registered_at');

        if (! $user->can('wash.view')) {
            $query->where('user_id', $user->id);
        }

        if ($request->filled('date_from')) {
            $query->where('registered_at', '>=',
                Carbon::parse($request->date_from, $tz)->startOfDay()
            );
        }

        if ($request->filled('date_to')) {
            $query->where('registered_at', '<=',
                Carbon::parse($request->date_to, $tz)->endOfDay()
            );
        }

        if ($request->filled('vehicle_type_id')) {
            $query->where('vehicle_type_id', $request->vehicle_type_id);
        }

        if ($request->filled('wash_service_id')) {
            $query->where('wash_service_id', $request->wash_service_id);
        }

        if ($user->can('wash.view') && $request->filled('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        return response()->json($query->paginate(20));
    }

    public function store(StoreWashRequest $request): JsonResponse
    {
        $service = WashService::findOrFail($request->wash_service_id);

        if ($service->is_custom) {
            $price              = $request->price;
            $customDescription  = $request->custom_description;
        } else {
            // El precio siempre viene del catálogo; se ignora cualquier price del request
            if (is_null($service->base_price)) {
                return response()->json([
                    'message' => 'El servicio "' . $service->name . '" no tiene precio configurado. Configúralo en el catálogo antes de registrar lavados.',
                ], 422);
            }

            $price             = $service->base_price;
            $customDescription = null;
        }

        $registeredAt = $request->filled('registered_at')
            ? Carbon::parse($request->registered_at, config('app.timezone'))
            : now();

        $wash = Wash::create([
            'user_id'            => $request->user()->id,
            'vehicle_type_id'    => $request->vehicle_type_id,
            'wash_service_id'    => $request->wash_service_id,
            'custom_description' => $customDescription,
            'price'              => $price,
            'status'             => 'completado',
            'notes'              => $request->notes,
            'registered_at'      => $registeredAt,
        ]);

        $wash->load(['vehicleType', 'washService', 'user:id,name']);

        return response()->json($wash, 201);
    }

    public function show(Wash $wash): JsonResponse
    {
        if (! request()->user()->can('wash.view') && $wash->user_id !== request()->user()->id) {
            abort(403);
        }

        $wash->load(['vehicleType', 'washService', 'user:id,name']);

        return response()->json($wash);
    }

    public function cancel(Request $request, Wash $wash): JsonResponse
    {
        if ($wash->status === 'anulado') {
            return response()->json(
                ['message' => 'Este lavado ya está anulado.'],
                422
            );
        }

        $wash->update([
            'status' => 'anulado',
            'notes'  => $request->notes ?? $wash->notes,
        ]);

        return response()->json($wash);
    }
}
