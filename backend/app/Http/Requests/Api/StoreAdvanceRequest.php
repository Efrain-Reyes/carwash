<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StoreAdvanceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'amount'       => 'required|numeric|min:0.01',
            'advance_date' => 'required|date',
            'notes'        => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'amount.required'       => 'El monto del adelanto es obligatorio.',
            'amount.min'            => 'El monto debe ser mayor a cero.',
            'advance_date.required' => 'La fecha del adelanto es obligatoria.',
        ];
    }
}
