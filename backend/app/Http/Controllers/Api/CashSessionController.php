<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AdjustCashSessionCloseRequest;
use App\Http\Requests\Api\CloseCashSessionRequest;
use App\Http\Requests\Api\StoreCashSessionRequest;
use App\Models\CashSession;
use App\Models\CashSessionAdjustment;
use App\Services\AccountingReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

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

        return response()->json(
            $query->paginate(20)->through(fn (CashSession $session) => $this->serializeSession($session))
        );
    }

    public function current(): JsonResponse
    {
        $tz = config('app.timezone');
        $todayStart = now($tz)->startOfDay();
        $todayEnd = $todayStart->copy()->endOfDay();

        $openSession = CashSession::with(['openedBy:id,name', 'closedBy:id,name'])
            ->where('status', 'abierta')
            ->orderBy('opened_at')
            ->orderBy('id')
            ->first();

        if ($openSession) {
            $pendingClosure = $openSession->opened_at->lt($todayStart);

            return response()->json([
                'cash_session' => $this->serializeCurrentSession($openSession, $todayEnd),
                'message' => $pendingClosure ? 'Hay una caja pendiente de cierre.' : null,
                'requires_first_cash_session' => false,
                'pending_closure' => $pendingClosure,
                'opened_automatically' => false,
            ]);
        }

        $todaySession = CashSession::with(['openedBy:id,name', 'closedBy:id,name'])
            ->whereBetween('opened_at', [$todayStart, $todayEnd])
            ->orderByDesc('opened_at')
            ->orderByDesc('id')
            ->first();

        if ($todaySession) {
            return response()->json([
                'cash_session' => $this->serializeCurrentSession($todaySession, $todayEnd),
                'message' => null,
                'requires_first_cash_session' => false,
                'pending_closure' => false,
                'opened_automatically' => false,
            ]);
        }

        $lastSession = CashSession::with(['openedBy:id,name', 'closedBy:id,name'])
            ->orderByDesc('closed_at')
            ->orderByDesc('opened_at')
            ->orderByDesc('id')
            ->first();

        if (! $lastSession) {
            return response()->json([
                'cash_session' => null,
                'message' => 'No existe ninguna caja previa. El administrador debe crear la primera caja.',
                'requires_first_cash_session' => true,
                'pending_closure' => false,
                'opened_automatically' => false,
            ]);
        }

        if ($lastSession->status !== 'cerrada') {
            return response()->json([
                'cash_session' => $this->serializeCurrentSession($lastSession, $todayEnd),
                'message' => 'Hay una caja pendiente de cierre.',
                'requires_first_cash_session' => false,
                'pending_closure' => true,
                'opened_automatically' => false,
            ]);
        }

        if ($lastSession->counted_closing_amount === null) {
            return response()->json([
                'cash_session' => null,
                'message' => 'La última caja cerrada no tiene efectivo total contado en caja.',
                'requires_first_cash_session' => false,
                'pending_closure' => false,
                'opened_automatically' => false,
            ], 422);
        }

        $session = CashSession::create([
            'opening_amount' => round((float) $lastSession->counted_closing_amount, 2),
            'opened_at' => $todayStart,
            'status' => 'abierta',
            'opened_by' => null,
            'notes' => 'Caja abierta automáticamente desde el cierre anterior',
        ])->load(['openedBy:id,name', 'closedBy:id,name']);

        return response()->json([
            'cash_session' => $this->serializeCurrentSession($session, $todayEnd),
            'message' => null,
            'requires_first_cash_session' => false,
            'pending_closure' => false,
            'opened_automatically' => true,
        ]);
    }

    public function store(StoreCashSessionRequest $request): JsonResponse
    {
        if (CashSession::where('status', 'abierta')->exists()) {
            return response()->json([
                'message' => 'Ya existe una caja abierta. Debes cerrarla antes de abrir otra.',
            ], 422);
        }

        if (CashSession::exists()) {
            return response()->json([
                'message' => 'La primera caja ya fue creada. Las siguientes cajas se abren automáticamente desde el cierre anterior.',
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
        $cashSession->load([
            'openedBy:id,name',
            'closedBy:id,name',
            'adjustments.user:id,name',
        ]);

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

    public function adjustClosing(AdjustCashSessionCloseRequest $request, CashSession $cashSession): JsonResponse
    {
        if ($cashSession->status !== 'cerrada') {
            return response()->json([
                'message' => 'Solo se pueden editar cierres de cajas cerradas.',
            ], 422);
        }

        $warning = null;
        $nextSessionUpdated = false;

        DB::transaction(function () use ($request, $cashSession, &$warning, &$nextSessionUpdated) {
            $cashSession->refresh();

            $expectedClosing = $cashSession->expected_closing_amount !== null
                ? round((float) $cashSession->expected_closing_amount, 2)
                : $this->expectedClosingForSession($cashSession);
            $countedClosing = round((float) $request->counted_closing_amount, 2);
            $difference = round($countedClosing - $expectedClosing, 2);
            $newNotes = $request->input('notes');

            CashSessionAdjustment::create([
                'cash_session_id' => $cashSession->id,
                'user_id' => $request->user()?->id,
                'old_counted_closing_amount' => $cashSession->counted_closing_amount,
                'new_counted_closing_amount' => $countedClosing,
                'old_difference' => $cashSession->difference,
                'new_difference' => $difference,
                'old_notes' => $cashSession->notes,
                'new_notes' => $newNotes,
                'reason' => $request->reason,
            ]);

            $cashSession->update([
                'expected_closing_amount' => $expectedClosing,
                'counted_closing_amount' => $countedClosing,
                'difference' => $difference,
                'notes' => $newNotes,
            ]);

            $nextSession = CashSession::query()
                ->where('opened_at', '>', $cashSession->opened_at)
                ->orderBy('opened_at')
                ->orderBy('id')
                ->first();

            if (! $nextSession) {
                return;
            }

            if ($nextSession->status === 'abierta') {
                $nextExpected = $this->expectedClosingForSession($nextSession, $countedClosing);

                $nextSession->update([
                    'opening_amount' => $countedClosing,
                    'expected_closing_amount' => $nextExpected,
                ]);

                $nextSessionUpdated = true;

                return;
            }

            $warning = 'Existe una caja posterior ya cerrada. No se modificó la cadena automáticamente; revise el historial y registre los ajustes necesarios con evidencia.';
        });

        $cashSession->load([
            'openedBy:id,name',
            'closedBy:id,name',
            'adjustments.user:id,name',
        ]);

        return response()->json([
            'cash_session' => $this->serializeSession($cashSession),
            'next_session_updated' => $nextSessionUpdated,
            'warning' => $warning,
        ]);
    }

    private function serializeSession(CashSession $session): array
    {
        $data = [
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
            'needs_review' => $session->status === 'cerrada'
                && $session->difference !== null
                && (float) $session->difference < 0,
        ];

        if ($session->relationLoaded('adjustments')) {
            $data['adjustments'] = $session->adjustments
                ->sortByDesc('created_at')
                ->values()
                ->map(fn (CashSessionAdjustment $adjustment) => $this->serializeAdjustment($adjustment))
                ->toArray();
        }

        return $data;
    }

    private function serializeCurrentSession(CashSession $session, Carbon $expectedAt): array
    {
        $data = $this->serializeSession($session);

        $movement = $this->reportService->cashMovementBetween(
            $session->opened_at->copy()->startOfDay(),
            ($session->closed_at ?? $expectedAt)->copy()->endOfDay(),
        );

        $data['movimiento_neto_efectivo'] = (float) $movement['movimiento_neto_efectivo'];

        if ($session->status === 'abierta') {
            $expectedClosing = $this->reportService->calculateExpectedClosing(
                (float) $session->opening_amount,
                (float) $movement['movimiento_neto_efectivo'],
            );

            $data['expected_closing_amount'] = $expectedClosing;
            $data['saldo_final_estimado'] = $expectedClosing;
        }

        return $data;
    }

    private function expectedClosingForSession(CashSession $session, ?float $openingAmount = null): float
    {
        $tz = config('app.timezone');
        $to = $session->closed_at ?? now($tz)->endOfDay();

        $movement = $this->reportService->cashMovementBetween(
            $session->opened_at->copy()->startOfDay(),
            $to->copy()->endOfDay(),
        );

        return $this->reportService->calculateExpectedClosing(
            $openingAmount ?? (float) $session->opening_amount,
            (float) $movement['movimiento_neto_efectivo'],
        );
    }

    private function serializeAdjustment(CashSessionAdjustment $adjustment): array
    {
        return [
            'id' => $adjustment->id,
            'cash_session_id' => $adjustment->cash_session_id,
            'user_id' => $adjustment->user_id,
            'user' => $adjustment->user ? [
                'id' => $adjustment->user->id,
                'name' => $adjustment->user->name,
            ] : null,
            'old_counted_closing_amount' => $adjustment->old_counted_closing_amount !== null ? (float) $adjustment->old_counted_closing_amount : null,
            'new_counted_closing_amount' => (float) $adjustment->new_counted_closing_amount,
            'old_difference' => $adjustment->old_difference !== null ? (float) $adjustment->old_difference : null,
            'new_difference' => (float) $adjustment->new_difference,
            'old_notes' => $adjustment->old_notes,
            'new_notes' => $adjustment->new_notes,
            'reason' => $adjustment->reason,
            'created_at' => $adjustment->created_at?->toDateTimeString(),
        ];
    }
}
