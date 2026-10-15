<?php

namespace App\Http\Requests\Api;

use App\Models\WashService;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Support\Collection;

/**
 * Registro de uno o varios servicios para un mismo vehículo: como máximo un lavado
 * y los extras que se quieran (o solo extras).
 *
 * Formato actual:  { vehicle_type_id, items: [{ wash_service_id, price?, custom_description? }], notes?, registered_at? }
 * Formato anterior (APK vieja): { vehicle_type_id, wash_service_id, price?, custom_description?, ... }
 */
class StoreWashRequest extends FormRequest
{
    private ?Collection $services = null;

    public function authorize(): bool
    {
        return true;
    }

    /** true si llegó en el formato anterior de un solo servicio. */
    public function isLegacy(): bool
    {
        return (bool) $this->attributes->get('legacy_format', false);
    }

    protected function prepareForValidation(): void
    {
        if (! $this->has('items') && $this->has('wash_service_id')) {
            $this->attributes->set('legacy_format', true);

            $this->merge(['items' => [[
                'wash_service_id'    => $this->input('wash_service_id'),
                'price'              => $this->input('price'),
                'custom_description' => $this->input('custom_description'),
            ]]]);
        }
    }

    public function rules(): array
    {
        return [
            'vehicle_type_id'            => 'required|integer|exists:vehicle_types,id',
            'items'                      => 'required|array|min:1|max:10',
            'items.*.wash_service_id'    => 'required|integer|distinct|exists:wash_services,id',
            'items.*.custom_description' => 'nullable|string|max:255',
            'items.*.price'              => 'nullable|numeric|min:0',
            'notes'                      => 'nullable|string|max:500',
            'registered_at'              => 'nullable|date',
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            $washCount = 0;

            foreach ($this->input('items') as $i => $item) {
                $service = $this->services()->get((int) $item['wash_service_id']);
                $field = "items.{$i}";

                if ($service->vehicle_type_id !== (int) $this->vehicle_type_id) {
                    $validator->errors()->add("{$field}.wash_service_id", 'El servicio no corresponde al tipo de vehículo seleccionado.');

                    continue;
                }

                // Desactivado desde el catálogo (el precio para ese vehículo o el servicio completo).
                if (! $service->is_active || $service->serviceType?->is_active === false) {
                    $validator->errors()->add("{$field}.wash_service_id", "«{$service->name}» ya no está disponible. Actualiza la pantalla e intenta de nuevo.");

                    continue;
                }

                if ($service->is_custom) {
                    if (blank($item['custom_description'] ?? null)) {
                        $validator->errors()->add("{$field}.custom_description", "Describe qué se hizo en «{$service->name}».");
                    }
                    if (($item['price'] ?? null) === null || $item['price'] === '') {
                        $validator->errors()->add("{$field}.price", "Ingresa el precio de «{$service->name}».");
                    }
                } elseif ($service->base_price === null) {
                    $validator->errors()->add("{$field}.wash_service_id", "«{$service->name}» no tiene precio configurado. Configúralo en el catálogo.");
                }

                if (! $service->isExtra()) {
                    $washCount++;
                }
            }

            if ($washCount > 1) {
                $validator->errors()->add('items', 'Solo se puede registrar un lavado por vehículo; lo demás deben ser extras.');
            }
        });
    }

    /** En el formato anterior los errores conservan sus nombres de siempre (price, wash_service_id...). */
    protected function failedValidation(Validator $validator): void
    {
        if (! $this->isLegacy()) {
            parent::failedValidation($validator);
        }

        $errors = collect($validator->errors()->messages())
            ->mapWithKeys(fn (array $messages, string $key) => [preg_replace('/^items\.0\./', '', $key) => $messages]);

        throw new HttpResponseException(response()->json([
            'message' => $validator->errors()->first(),
            'errors'  => $errors,
        ], 422));
    }

    /** Servicios pedidos, indexados por id. */
    public function services(): Collection
    {
        return $this->services ??= WashService::with('serviceType')
            ->findMany(collect($this->input('items', []))->pluck('wash_service_id'))
            ->keyBy('id');
    }

    public function messages(): array
    {
        return [
            'vehicle_type_id.required'         => 'Selecciona el tipo de vehículo.',
            'vehicle_type_id.exists'           => 'El tipo de vehículo no es válido.',
            'items.required'                   => 'Selecciona al menos un servicio.',
            'items.min'                        => 'Selecciona al menos un servicio.',
            'items.*.wash_service_id.required' => 'Selecciona el servicio.',
            'items.*.wash_service_id.exists'   => 'El servicio no es válido.',
            'items.*.wash_service_id.distinct' => 'Ese servicio está repetido.',
            'items.*.price.numeric'            => 'El precio debe ser un número.',
            'items.*.price.min'                => 'El precio no puede ser negativo.',
        ];
    }
}
