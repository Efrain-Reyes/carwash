<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class AdjustCashSessionCloseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'counted_closing_amount' => 'required|numeric|min:0',
            'notes' => 'nullable|string|max:1000',
            'reason' => 'required|string|max:1000',
        ];
    }

    public function messages(): array
    {
        return [
            'counted_closing_amount.required' => 'El efectivo total contado en caja es obligatorio.',
            'counted_closing_amount.min' => 'El efectivo total contado en caja no puede ser negativo.',
            'reason.required' => 'El motivo del ajuste es obligatorio.',
        ];
    }
}
