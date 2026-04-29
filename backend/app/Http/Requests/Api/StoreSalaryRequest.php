<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StoreSalaryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'salary'               => 'required|numeric|min:0',
            'payment_frequency'    => 'required|in:diario,semanal,quincenal,mensual,otro',
            'work_days_per_period' => 'required|integer|min:1|max:31',
            'effective_from'       => 'required|date',
            'notes'                => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'salary.required'               => 'El sueldo es obligatorio.',
            'payment_frequency.required'    => 'La frecuencia de pago es obligatoria.',
            'payment_frequency.in'          => 'Frecuencia inválida. Usa: diario, semanal, quincenal, mensual u otro.',
            'work_days_per_period.required' => 'Los días laborables son obligatorios.',
            'effective_from.required'       => 'La fecha de inicio del nuevo sueldo es obligatoria.',
        ];
    }
}
