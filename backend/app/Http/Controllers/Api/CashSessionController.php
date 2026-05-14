<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\CloseCashSessionRequest;
use App\Http\Requests\Api\StoreCashSessionRequest;
use App\Models\CashSession;
use App\Services\AccountingReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class CashSessionController extends Controller
{
    public function __construct(private AccountingReportService $reportService) {}

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'status' => 'sometimes|in:abierta,cerrada',
            'date_from' => 'sometimes|date',
            'date_to' => 'sometimes|date|after_or_equal:date_from',
        ]);

        $tz = config('app.timezone');

        $query = CashSession::with(['openedBy:id,name', 'closedBy:id,name'])
            ->orderByDesc('opened_at')
            ->orderByDesc('id');

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('date_from')) {
            $query->where('opened_at', '>=', Carbon::parse($request->date_from, $tz)->startOfDay());
        }

        if ($request->filled('date_to')) {
            $query->where('opened_at', '<=', Carbon::parse($request->date_to, $tz)->endOfDay());
        }

        return response()->json($query->paginate(20));
    }

    public function current(): JsonResponse
    {
        $session = CashSession::with(['openedBy:id,name', 'closedBy:id,name'])
            ->where('status', 'abierta')
            ->orderByDesc('opened_at')
            ->first();

        return response()->json([
            'cash_session' => $session ? $this->serializeSession($session) : null,
        ]);
    }

    public function store(StoreCashSessionRequest $request): JsonResponse
    {
        if (CashSession::where('status', 'abierta')->exists()) {
            return response()->json([
                'message' => 'Ya existe una caja abierta. Debes cerrarla antes de abrir otra.',
            ], 422);
        }

        $tz = config('app.timezone');
        $openedAt = $request->filled('opened_at')
            ? Carbon::parse($request->opened_at, $tz)
            : now($tz);
        $openingAmount = round((float) $request->opening_amount, 2);

        $session = CashSession::create([
            'opening_amount' => $openingAmount,
            'opened_at' => $openedAt,
            'status' => 'abierta',
            'opened_by' => $request->user()?->id,
            'notes' => $request->notes,
        ])->load(['openedBy:id,name', 'closedBy:id,name']);

        return response()->json([
            'cash_session' => $this->serializeSession($session),
        ], 201);
    }

    public function show(CashSession $cashSession): JsonResponse
    {
        $cashSession->load(['openedBy:id,name', 'closedBy:id,name']);

        return response()->json([
            'cash_session' => $this->serializeSession($cashSession),
        ]);
    }

    public function close(CloseCashSessionRequest $request, CashSession $cashSession): JsonResponse
    {
        if ($cashSession->status === 'cerrada') {
            return response()->json([
                'message' => 'Esta caja ya está cerrada.',
            ], 422);
        }

        $tz = config('app.timezone');
        $closedAt = $request->filled('closed_at')
            ? Carbon::parse($request->closed_at, $tz)
            : now($tz);

        if ($closedAt->lt($cashSession->opened_at)) {
            return response()->json([
                'message' => 'La fecha de cierre no puede ser anterior a la apertura.',
            ], 422);
        }

        $movement = $this->reportService->cashMovementBetween(
            $cashSession->opened_at->copy()->startOfDay(),
            $closedAt->copy()->endOfDay(),
        );

        $expectedClosing = $this->reportService->calculateExpectedClosing(
            (float) $cashSession->opening_amount,
            (float) $movement['movimiento_neto_efectivo'],
        );
        $countedClosing = round((float) $request->counted_closing_amount, 2);
        $difference = round($countedClosing - $expectedClosing, 2);

        $cashSession->update([
            'expected_closing_amount' => $expectedClosing,
            'counted_closing_amount' => $countedClosing,
            'difference' => $difference,
            'closed_at' => $closedAt,
            'status' => 'cerrada',
            'closed_by' => $request->user()?->id,
            'notes' => $request->notes ?? $cashSession->notes,
        ]);

        $cashSession->load(['openedBy:id,name', 'closedBy:id,name']);

        return response()->json([
            'cash_session' => $this->serializeSession($cashSession),
            'movimiento' => $movement,
        ]);
    }

    private function serializeSession(CashSession $session): array
    {
        return [
            'id' => $session->id,
            'opening_amount' => (float) $session->opening_amount,
            'expected_closing_amount' => $session->expected_closing_amount !== null ? (float) $session->expected_closing_amount : null,
            'counted_closing_amount' => $session->counted_closing_amount !== null ? (float) $session->counted_closing_amount : null,
            'difference' => $session->difference !== null ? (float) $session->difference : null,
            'saldo_inicial_caja' => (float) $session->opening_amount,
            'saldo_final_estimado' => $session->expected_closing_amount !== null ? (float) $session->expected_closing_amount : null,
            'efectivo_contado' => $session->counted_closing_amount !== null ? (float) $session->counted_closing_amount : null,
            'diferencia_caja' => $session->difference !== null ? (float) $session->difference : null,
            'opened_at' => $session->opened_at?->toDateTimeString(),
            'closed_at' => $session->closed_at?->toDateTimeString(),
            'status' => $session->status,
            'opened_by' => $session->openedBy ? [
                'id' => $session->openedBy->id,
                'name' => $session->openedBy->name,
            ] : null,
            'closed_by' => $session->closedBy ? [
                'id' => $session->closedBy->id,
                'name' => $session->closedBy->name,
            ] : null,
            'notes' => $session->notes,
        ];
    }
}
