<?php

namespace App\Http\Requests\Api;

use App\Models\WashService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWashRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $service  = WashService::find($this->wash_service_id);
        $isCustom = $service?->is_custom ?? false;

        return [
            'vehicle_type_id'    => 'required|integer|exists:vehicle_types,id',
            'wash_service_id'    => 'required|integer|exists:wash_services,id',
            'custom_description' => [Rule::requiredIf($isCustom), 'nullable', 'string', 'max:255'],
            'price'              => [Rule::requiredIf($isCustom), 'nullable', 'numeric', 'min:0'],
            'notes'              => 'nullable|string|max:500',
            'registered_at'      => 'nullable|date',
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            $service = WashService::find($this->wash_service_id);

            if (! $service) {
                return;
            }

            if ($service->vehicle_type_id !== (int) $this->vehicle_type_id) {
                $validator->errors()->add(
                    'wash_service_id',
                    'El servicio no corresponde al tipo de vehículo seleccionado.'
                );
            }
        });
    }

    public function messages(): array
    {
        return [
            'vehicle_type_id.required'    => 'Selecciona el tipo de vehículo.',
            'vehicle_type_id.exists'      => 'El tipo de vehículo no es válido.',
            'wash_service_id.required'    => 'Selecciona el servicio.',
            'wash_service_id.exists'      => 'El servicio no es válido.',
            'custom_description.required' => 'Describe qué se hizo en el servicio.',
            'price.required'              => 'Ingresa el precio del servicio.',
            'price.numeric'               => 'El precio debe ser un número.',
            'price.min'                   => 'El precio no puede ser negativo.',
        ];
    }
}
