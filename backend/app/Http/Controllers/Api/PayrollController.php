<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StorePayrollPaymentRequest;
use App\Http\Requests\Api\StorePayrollPeriodRequest;
use App\Models\Employee;
use App\Models\EmployeeAdvance;
use App\Models\PayrollPayment;
use App\Models\PayrollPeriod;
use App\Services\PayrollService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PayrollController extends Controller
{
    public function __construct(private PayrollService $payrollService) {}

    // ──────────────────────────────────────────────
    // Periodos
    // ──────────────────────────────────────────────

    public function indexPeriods(): JsonResponse
    {
        $periods = PayrollPeriod::withCount('payments')
            ->orderByDesc('start_date')
            ->orderByDesc('id')
            ->get();

        return response()->json($periods);
    }

    public function storePeriod(StorePayrollPeriodRequest $request): JsonResponse
    {
        $period = PayrollPeriod::create([
            'created_by' => $request->user()->id,
            'start_date' => $request->start_date,
            'end_date'   => $request->end_date,
            'status'     => 'abierto',
            'notes'      => $request->notes,
        ]);

        return response()->json($period, 201);
    }

    public function showPeriod(PayrollPeriod $period): JsonResponse
    {
        $period->load([
            'payments.employee',
            'payments.processor:id,name',
            'creator:id,name',
        ]);

        return response()->json($period);
    }

    public function closePeriod(PayrollPeriod $period): JsonResponse
    {
        if ($period->status !== 'abierto') {
            return response()->json(
                ['message' => 'Solo se pueden cerrar periodos con estado "abierto".'],
                422
            );
        }

        $period->update(['status' => 'cerrado']);

        return response()->json($period);
    }

    public function cancelPeriod(PayrollPeriod $period): JsonResponse
    {
        if ($period->status === 'anulado') {
            return response()->json(
                ['message' => 'Este periodo ya está anulado.'],
                422
            );
        }

        $period->update(['status' => 'anulado']);

        return response()->json($period);
    }

    // ──────────────────────────────────────────────
    // Pagos
    // ──────────────────────────────────────────────

    public function storePayment(StorePayrollPaymentRequest $request, PayrollPeriod $period): JsonResponse
    {
        if ($period->status !== 'abierto') {
            return response()->json(
                ['message' => 'No se pueden agregar pagos a un periodo cerrado o anulado.'],
                422
            );
        }

        $payment = $this->payrollService->createPayment(
            $period,
            $request->validated(),
            $request->user()->id
        );

        return response()->json($payment->load('employee'), 201);
    }

    public function showPayment(PayrollPayment $payment): JsonResponse
    {
        $payment->load([
            'period',
            'employee',
            'salaryHistory',
            'processor:id,name',
            'advancePayments.advance',
        ]);

        return response()->json($payment);
    }

    public function confirmPayment(PayrollPayment $payment): JsonResponse
    {
        if ($payment->status !== 'borrador') {
            return response()->json(
                ['message' => 'Solo se pueden confirmar pagos en estado "borrador".'],
                422
            );
        }

        $payment = $this->payrollService->confirmPayment($payment);

        return response()->json($payment);
    }

    public function cancelPayment(Request $request, PayrollPayment $payment): JsonResponse
    {
        if ($payment->status === 'anulado') {
            return response()->json(
                ['message' => 'Este pago ya está anulado.'],
                422
            );
        }

        if ($payment->status === 'pagado') {
            return response()->json(
                ['message' => 'No se puede anular un pago ya confirmado. Contacte al administrador del sistema.'],
                422
            );
        }

        $payment->update(['status' => 'anulado', 'notes' => $request->notes ?? $payment->notes]);

        return response()->json($payment);
    }

    // ──────────────────────────────────────────────
    // Preview para pre-cargar el formulario en Flutter
    // ──────────────────────────────────────────────

    public function payrollPreview(Employee $employee): JsonResponse
    {
        $currentSalary = $employee->currentSalary;

        $pendingAdvances = EmployeeAdvance::where('employee_id', $employee->id)
            ->whereIn('status', ['pendiente', 'parcialmente_pagado'])
            ->orderBy('advance_date')
            ->get(['id', 'amount', 'balance', 'advance_date', 'status']);

        return response()->json([
            'employee'        => [
                'id'        => $employee->id,
                'full_name' => $employee->fullName(),
                'is_active' => $employee->is_active,
            ],
            'current_salary'  => $currentSalary,
            'pending_advances' => [
                'total_balance' => $pendingAdvances->sum('balance'),
                'advances'      => $pendingAdvances,
            ],
        ]);
    }
}
