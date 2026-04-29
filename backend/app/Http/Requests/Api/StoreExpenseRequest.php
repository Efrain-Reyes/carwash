<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreExpenseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $isInternal = (bool) $this->is_internal_invoice;

        return [
            'supplier_id'          => 'required|integer|exists:expense_suppliers,id',
            'is_internal_invoice'  => 'required|boolean',
            'invoice_number'       => [Rule::requiredIf(! $isInternal), 'nullable', 'string', 'max:100'],
            'expense_date'         => 'required|date',
            'notes'                => 'nullable|string|max:1000',

            'items'                => 'required|array|min:1',
            'items.*.catalog_item_id' => 'nullable|integer|exists:expense_catalog_items,id',
            'items.*.description'     => 'required|string|max:255',
            'items.*.quantity'        => 'required|numeric|min:0.01',
            'items.*.unit_price'      => 'required|numeric|min:0',
            'items.*.tax_rate'        => 'nullable|numeric|min:0|max:100',
        ];
    }

    public function messages(): array
    {
        return [
            'supplier_id.required'           => 'Selecciona el proveedor.',
            'supplier_id.exists'             => 'El proveedor no es válido.',
            'is_internal_invoice.required'   => 'Indica si tiene número de factura.',
            'invoice_number.required'        => 'El número de factura es obligatorio.',
            'expense_date.required'          => 'La fecha del gasto es obligatoria.',
            'items.required'                 => 'El gasto debe tener al menos un ítem.',
            'items.min'                      => 'El gasto debe tener al menos un ítem.',
            'items.*.description.required'   => 'Cada ítem debe tener descripción.',
            'items.*.quantity.required'      => 'Cada ítem debe tener cantidad.',
            'items.*.quantity.min'           => 'La cantidad debe ser mayor a cero.',
            'items.*.unit_price.required'    => 'Cada ítem debe tener precio unitario.',
            'items.*.unit_price.min'         => 'El precio no puede ser negativo.',
        ];
    }
}
