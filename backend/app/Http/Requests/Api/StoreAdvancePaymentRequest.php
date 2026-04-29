<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAdvancePaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $isPayrollDiscount = $this->payment_type === 'descuento_nomina';

        return [
            'amount'             => 'required|numeric|min:0.01',
            'payment_type'       => 'required|in:descuento_nomina,abono_efectivo,ajuste_manual',
            'payment_date'       => 'required|date',
            'payroll_payment_id' => [
                Rule::requiredIf($isPayrollDiscount),
                'nullable',
                'integer',
                'exists:payroll_payments,id',
            ],
            'notes' => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'amount.required'              => 'El monto del pago es obligatorio.',
            'amount.min'                   => 'El monto debe ser mayor a cero.',
            'payment_type.required'        => 'El tipo de pago es obligatorio.',
            'payment_type.in'              => 'Tipo inválido. Usa: descuento_nomina, abono_efectivo o ajuste_manual.',
            'payment_date.required'        => 'La fecha del pago es obligatoria.',
            'payroll_payment_id.required'  => 'Debes indicar el pago de nómina al que corresponde el descuento.',
            'payroll_payment_id.exists'    => 'El pago de nómina indicado no existe.',
        ];
    }
}
