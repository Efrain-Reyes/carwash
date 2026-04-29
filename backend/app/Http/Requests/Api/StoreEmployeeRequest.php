<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StoreEmployeeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Datos personales
            'first_name'           => 'required|string|max:100',
            'last_name'            => 'required|string|max:100',
            'phone'                => 'nullable|string|max:20',
            'hire_date'            => 'required|date',
            'user_id'              => 'nullable|integer|exists:users,id',

            // Sueldo inicial (obligatorio al crear)
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
            'first_name.required'           => 'El nombre es obligatorio.',
            'last_name.required'            => 'El apellido es obligatorio.',
            'hire_date.required'            => 'La fecha de contratación es obligatoria.',
            'salary.required'               => 'El sueldo es obligatorio.',
            'payment_frequency.required'    => 'La frecuencia de pago es obligatoria.',
            'payment_frequency.in'          => 'Frecuencia inválida. Usa: diario, semanal, quincenal, mensual u otro.',
            'work_days_per_period.required' => 'Los días laborables por periodo son obligatorios.',
            'work_days_per_period.min'      => 'Debe haber al menos 1 día laborable.',
            'effective_from.required'       => 'La fecha de inicio del sueldo es obligatoria.',
        ];
    }
}
