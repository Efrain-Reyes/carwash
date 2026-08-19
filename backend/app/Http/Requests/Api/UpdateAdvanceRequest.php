<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class UpdateAdvanceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'amount'       => 'sometimes|numeric|min:0.01',
            'advance_date' => 'sometimes|date',
            'notes'        => 'sometimes|nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'amount.min' => 'El monto debe ser mayor a cero.',
        ];
    }
}
