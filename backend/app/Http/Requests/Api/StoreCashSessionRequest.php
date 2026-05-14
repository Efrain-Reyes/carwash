<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StoreCashSessionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'opening_amount' => 'required|numeric|min:0',
            'opened_at' => 'nullable|date',
            'notes' => 'nullable|string|max:1000',
        ];
    }

    public function messages(): array
    {
        return [
            'opening_amount.required' => 'El efectivo inicial es obligatorio.',
            'opening_amount.min' => 'El efectivo inicial no puede ser negativo.',
        ];
    }
}
