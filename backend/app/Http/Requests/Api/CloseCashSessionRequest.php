<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class CloseCashSessionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'counted_closing_amount' => 'required|numeric|min:0',
            'closed_at' => 'nullable|date',
            'notes' => 'nullable|string|max:1000',
        ];
    }

    public function messages(): array
    {
        return [
            'counted_closing_amount.required' => 'El efectivo contado es obligatorio.',
            'counted_closing_amount.min' => 'El efectivo contado no puede ser negativo.',
        ];
    }
}
