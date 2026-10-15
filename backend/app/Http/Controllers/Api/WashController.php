<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreWashRequest;
use App\Models\CashSession;
use App\Models\Wash;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

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

        if ($request->filled('cash_session_id')) {
            $query->where('cash_session_id', $request->cash_session_id);
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
        $services = $request->services();

        $registeredAt = $request->filled('registered_at')
            ? Carbon::parse($request->registered_at, config('app.timezone'))
            : now();

        // Lo que se registra junto (un lavado y sus extras) comparte group_uuid y caja.
        $groupUuid = (string) Str::uuid();

        $washes = DB::transaction(function () use ($request, $services, $registeredAt, $groupUuid) {
            $cashSessionId = CashSession::openSessionIdForUpdate();

            return collect($request->input('items'))->map(function (array $item) use ($request, $services, $registeredAt, $groupUuid, $cashSessionId) {
                $service = $services->get((int) $item['wash_service_id']);

                return Wash::create([
                    'group_uuid'         => $groupUuid,
                    'user_id'            => $request->user()->id,
                    'cash_session_id'    => $cashSessionId,
                    'vehicle_type_id'    => $request->vehicle_type_id,
                    'wash_service_id'    => $service->id,
                    // Precio libre ("Otro"): lo escribe el operador. Si no, siempre el del catálogo.
                    'custom_description' => $service->is_custom ? trim($item['custom_description']) : null,
                    'price'              => $service->is_custom ? $item['price'] : $service->base_price,
                    'status'             => 'completado',
                    'notes'              => $request->notes,
                    'registered_at'      => $registeredAt,
                ]);
            });
        });

        $washes->each->load(['vehicleType', 'washService', 'user:id,name']);

        // La APK vieja espera el lavado suelto.
        if ($request->isLegacy()) {
            return response()->json($washes->first(), 201);
        }

        return response()->json([
            'washes' => $washes,
            'total'  => round($washes->sum(fn (Wash $wash) => (float) $wash->price), 2),
        ], 201);
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
