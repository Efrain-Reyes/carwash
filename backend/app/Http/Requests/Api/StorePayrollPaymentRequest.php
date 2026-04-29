<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StorePayrollPaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'employee_id'       => 'required|integer|exists:employees,id',
            'salary_history_id' => 'required|integer|exists:employee_salary_histories,id',
            'days_worked'       => 'required|numeric|min:0',
            'extra_payments'    => 'nullable|numeric|min:0',
            'advance_discount'  => 'nullable|numeric|min:0',
            'other_deductions'  => 'nullable|numeric|min:0',
            'payment_date'      => 'required|date',
            'notes'             => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'employee_id.required'        => 'Selecciona el trabajador.',
            'employee_id.exists'          => 'El trabajador no existe.',
            'salary_history_id.required'  => 'Selecciona el registro de sueldo.',
            'salary_history_id.exists'    => 'El registro de sueldo no existe.',
            'days_worked.required'        => 'Los días trabajados son obligatorios.',
            'days_worked.min'             => 'Los días trabajados no pueden ser negativos.',
            'payment_date.required'       => 'La fecha de pago es obligatoria.',
        ];
    }
}
