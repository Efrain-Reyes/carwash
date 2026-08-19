<?php

namespace App\Services;

use App\Models\CashSession;
use App\Models\EmployeeAdvance;
use App\Models\EmployeeAdvancePayment;
use Illuminate\Support\Facades\DB;

class AdvanceService
{
    public function create(int $employeeId, array $data, int $userId): EmployeeAdvance
    {
        return DB::transaction(fn () => EmployeeAdvance::create([
            'employee_id'     => $employeeId,
            'cash_session_id' => CashSession::openSessionIdForUpdate(),
            'user_id'         => $userId,
            'amount'          => $data['amount'],
            'balance'         => $data['amount'], // balance inicia igual al monto entregado
            'advance_date'    => $data['advance_date'],
            'status'          => 'pendiente',
            'notes'           => $data['notes'] ?? null,
        ]));
    }

    /**
     * Edita un adelanto no pagado (pendiente o parcialmente_pagado). El balance
     * nunca se edita directamente: siempre se recalcula como amount - pagado,
     * para que nunca quede inconsistente con los abonos ya registrados.
     */
    public function update(EmployeeAdvance $advance, array $data): EmployeeAdvance
    {
        if (in_array($advance->status, ['pagado', 'anulado'], true)) {
            throw new \InvalidArgumentException(
                'No se puede editar un adelanto ya pagado o anulado.'
            );
        }

        $paidSoFar = round((float) $advance->amount - (float) $advance->balance, 2);
        $newAmount = array_key_exists('amount', $data) ? (float) $data['amount'] : (float) $advance->amount;

        if ($newAmount < $paidSoFar) {
            throw new \InvalidArgumentException(
                "El nuevo monto (L {$newAmount}) no puede ser menor a lo ya abonado (L {$paidSoFar})."
            );
        }

        $advance->fill(array_intersect_key($data, array_flip(['amount', 'advance_date', 'notes'])));

        $newBalance = round($newAmount - $paidSoFar, 2);
        $advance->balance = $newBalance;
        $advance->status = $newBalance <= 0 ? 'pagado' : ($paidSoFar > 0 ? 'parcialmente_pagado' : 'pendiente');

        $advance->save();

        return $advance;
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
                'cash_session_id'    => CashSession::openSessionIdForUpdate(),
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
