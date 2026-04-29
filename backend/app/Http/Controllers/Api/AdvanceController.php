<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreAdvancePaymentRequest;
use App\Http\Requests\Api\StoreAdvanceRequest;
use App\Models\Employee;
use App\Models\EmployeeAdvance;
use App\Services\AdvanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdvanceController extends Controller
{
    public function __construct(private AdvanceService $advanceService) {}

    public function all(Request $request): JsonResponse
    {
        $request->validate([
            'status' => 'sometimes|in:pendiente,parcialmente_pagado,pagado,anulado',
        ]);

        $advances = EmployeeAdvance::query()
            ->with([
                'employee',
                'registeredBy:id,name',
                'payments' => fn ($q) => $q->orderByDesc('payment_date')->orderByDesc('id'),
                'payments.registeredBy:id,name',
            ])
            ->withSum('payments', 'amount')
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->status))
            ->orderByDesc('advance_date')
            ->orderByDesc('id')
            ->get();

        return response()->json($advances);
    }

    public function index(Employee $employee): JsonResponse
    {
        $advances = $employee->advances()
            ->withSum('payments', 'amount')
            ->orderByDesc('advance_date')
            ->orderByDesc('id')
            ->get();

        return response()->json($advances);
    }

    public function store(StoreAdvanceRequest $request, Employee $employee): JsonResponse
    {
        $advance = $this->advanceService->create(
            $employee->id,
            $request->validated(),
            $request->user()->id
        );

        return response()->json($advance->load('registeredBy:id,name'), 201);
    }

    public function show(EmployeeAdvance $advance): JsonResponse
    {
        $advance->load([
            'employee',
            'registeredBy:id,name',
            'payments' => fn ($q) => $q->orderByDesc('payment_date')->orderByDesc('id'),
            'payments.registeredBy:id,name',
        ]);

        return response()->json($advance);
    }

    public function storePayment(StoreAdvancePaymentRequest $request, EmployeeAdvance $advance): JsonResponse
    {
        if ($advance->status === 'pagado') {
            return response()->json(
                ['message' => 'Este adelanto ya está completamente pagado.'],
                422
            );
        }

        if ($advance->status === 'anulado') {
            return response()->json(
                ['message' => 'No se puede registrar un pago sobre un adelanto anulado.'],
                422
            );
        }

        try {
            $payment = $this->advanceService->registerPayment(
                $advance,
                $request->validated(),
                $request->user()->id
            );
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        // Devolver el adelanto actualizado con el nuevo pago
        $advance->refresh();

        return response()->json([
            'payment'          => $payment,
            'advance_balance'  => $advance->balance,
            'advance_status'   => $advance->status,
        ], 201);
    }

    public function cancel(Request $request, EmployeeAdvance $advance): JsonResponse
    {
        if ($advance->status === 'anulado') {
            return response()->json(
                ['message' => 'Este adelanto ya está anulado.'],
                422
            );
        }

        if ($advance->status === 'pagado') {
            return response()->json(
                ['message' => 'No se puede anular un adelanto que ya fue pagado completamente.'],
                422
            );
        }

        $advance->update([
            'status' => 'anulado',
            'notes'  => $request->notes ?? $advance->notes,
        ]);

        return response()->json($advance);
    }
}
