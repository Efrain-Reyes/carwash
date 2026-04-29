<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StorePayrollPeriodRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'start_date' => 'required|date',
            'end_date'   => 'required|date|after_or_equal:start_date',
            'notes'      => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'start_date.required'          => 'La fecha de inicio es obligatoria.',
            'end_date.required'            => 'La fecha de fin es obligatoria.',
            'end_date.after_or_equal'      => 'La fecha de fin debe ser igual o posterior a la de inicio.',
        ];
    }
}
