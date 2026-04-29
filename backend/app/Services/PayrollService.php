<?php

namespace App\Services;

use App\Models\EmployeeAdvance;
use App\Models\EmployeeAdvancePayment;
use App\Models\EmployeeSalaryHistory;
use App\Models\PayrollPayment;
use App\Models\PayrollPeriod;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PayrollService
{
    public function createPayment(PayrollPeriod $period, array $data, int $userId): PayrollPayment
    {
        $advanceDiscount = $data['advance_discount'] ?? 0;

        if ($advanceDiscount > 0) {
            $this->validateAdvanceDiscount($data['employee_id'], $advanceDiscount);
        }

        $salaryHistory = EmployeeSalaryHistory::findOrFail($data['salary_history_id']);

        $grossAmount     = round($data['days_worked'] * $salaryHistory->daily_rate, 2);
        $extraPayments   = $data['extra_payments'] ?? 0;
        $otherDeductions = $data['other_deductions'] ?? 0;
        $netAmount       = round($grossAmount + $extraPayments - $advanceDiscount - $otherDeductions, 2);

        return PayrollPayment::create([
            'payroll_period_id'    => $period->id,
            'employee_id'          => $data['employee_id'],
            'salary_history_id'    => $salaryHistory->id,
            'processed_by'         => $userId,
            'base_salary'          => $salaryHistory->salary,
            'daily_rate'           => $salaryHistory->daily_rate,
            'work_days_per_period' => $salaryHistory->work_days_per_period,
            'days_worked'          => $data['days_worked'],
            'gross_amount'         => $grossAmount,
            'extra_payments'       => $extraPayments,
            'advance_discount'     => $advanceDiscount,
            'other_deductions'     => $otherDeductions,
            'net_amount'           => $netAmount,
            'payment_date'         => $data['payment_date'],
            'status'               => 'borrador',
            'notes'                => $data['notes'] ?? null,
        ]);
    }

    public function confirmPayment(PayrollPayment $payment): PayrollPayment
    {
        return DB::transaction(function () use ($payment) {
            $payment->update(['status' => 'pagado']);

            if ($payment->advance_discount > 0) {
                $this->applyAdvanceDiscount($payment);
            }

            // refresh() fuerza recargar el modelo desde la BD incluyendo las relaciones recién creadas
            $payment->refresh();

            return $payment->load([
                'employee',
                'period',
                'processor:id,name',
                'advancePayments.advance',
                'advancePayments.registeredBy:id,name',
            ]);
        });
    }

    private function validateAdvanceDiscount(int $employeeId, float $advanceDiscount): void
    {
        $totalPendingBalance = EmployeeAdvance::where('employee_id', $employeeId)
            ->whereIn('status', ['pendiente', 'parcialmente_pagado'])
            ->sum('balance');

        if ($totalPendingBalance <= 0) {
            throw ValidationException::withMessages([
                'advance_discount' => 'Este empleado no tiene adelantos pendientes.',
            ]);
        }

        if ($advanceDiscount > $totalPendingBalance) {
            throw ValidationException::withMessages([
                'advance_discount' => "El descuento (L {$advanceDiscount}) supera el total de adelantos pendientes (L {$totalPendingBalance}).",
            ]);
        }
    }

    private function applyAdvanceDiscount(PayrollPayment $payment): void
    {
        $remaining = $payment->advance_discount;

        $advances = EmployeeAdvance::where('employee_id', $payment->employee_id)
            ->whereIn('status', ['pendiente', 'parcialmente_pagado'])
            ->orderBy('advance_date')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        foreach ($advances as $advance) {
            if ($remaining <= 0) {
                break;
            }

            $deduction  = min($remaining, (float) $advance->balance);
            $newBalance = round((float) $advance->balance - $deduction, 2);

            EmployeeAdvancePayment::create([
                'advance_id'         => $advance->id,
                'payroll_payment_id' => $payment->id,
                'user_id'            => $payment->processed_by,
                'amount'             => $deduction,
                'payment_type'       => 'descuento_nomina',
                'payment_date'       => $payment->payment_date,
                'notes'              => 'Descuento aplicado automáticamente desde nómina.',
            ]);

            $advance->update([
                'balance' => $newBalance,
                'status'  => $newBalance <= 0 ? 'pagado' : 'parcialmente_pagado',
            ]);

            $remaining -= $deduction;
        }
    }
}
