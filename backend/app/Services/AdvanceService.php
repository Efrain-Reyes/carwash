<?php

namespace App\Services;

use App\Models\EmployeeAdvance;
use App\Models\EmployeeAdvancePayment;
use Illuminate\Support\Facades\DB;

class AdvanceService
{
    public function create(int $employeeId, array $data, int $userId): EmployeeAdvance
    {
        return EmployeeAdvance::create([
            'employee_id'  => $employeeId,
            'user_id'      => $userId,
            'amount'       => $data['amount'],
            'balance'      => $data['amount'], // balance inicia igual al monto entregado
            'advance_date' => $data['advance_date'],
            'status'       => 'pendiente',
            'notes'        => $data['notes'] ?? null,
        ]);
    }

    public function registerPayment(EmployeeAdvance $advance, array $data, int $userId): EmployeeAdvancePayment
    {
        return DB::transaction(function () use ($advance, $data, $userId) {
            if ($data['amount'] > $advance->balance) {
                throw new \InvalidArgumentException(
                    "El pago (L {$data['amount']}) supera el saldo pendiente (L {$advance->balance})."
                );
            }

            $payment = EmployeeAdvancePayment::create([
                'advance_id'         => $advance->id,
                'payroll_payment_id' => $data['payroll_payment_id'] ?? null,
                'user_id'            => $userId,
                'amount'             => $data['amount'],
                'payment_type'       => $data['payment_type'],
                'payment_date'       => $data['payment_date'],
                'notes'              => $data['notes'] ?? null,
            ]);

            $newBalance = round($advance->balance - $data['amount'], 2);

            $advance->update([
                'balance' => $newBalance,
                'status'  => $newBalance <= 0 ? 'pagado' : 'parcialmente_pagado',
            ]);

            return $payment;
        });
    }
}
