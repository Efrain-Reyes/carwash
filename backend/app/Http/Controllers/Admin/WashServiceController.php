<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Admin\Concerns\ValidatesInSpanish;
use App\Http\Controllers\Controller;
use App\Models\VehicleType;
use App\Models\WashService;
use App\Models\WashServiceType;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/** Catálogo de servicios y matriz de precios (servicio × tipo de vehículo). */
class WashServiceController extends Controller
{
    use ValidatesInSpanish;

    public function index(): View
    {
        $vehicleTypes = VehicleType::ordered()->get();
        $serviceTypes = WashServiceType::ordered()->with('prices')->get();

        // $matrix[servicio][vehículo] = WashService (o null si nunca se ha ofrecido)
        $matrix = $serviceTypes->mapWithKeys(fn (WashServiceType $type) => [
            $type->id => $type->prices->keyBy('vehicle_type_id'),
        ]);

        return view('admin.catalog.services.index', compact('vehicleTypes', 'serviceTypes', 'matrix'));
    }

    /**
     * Guarda la matriz completa. Precio vacío = no se ofrece para ese vehículo
     * (se desactiva, no se borra, para no perder el historial de lavados).
     */
    public function updatePrices(Request $request): RedirectResponse
    {
        $this->validateForm($request, [
            'prices'     => 'array',
            'prices.*'   => 'array',
            'prices.*.*' => 'nullable|numeric|min:0|max:999999',
            'offered'    => 'array',
        ], ['prices.*.*' => 'precio']);

        $vehicleTypes = VehicleType::all();
        $serviceTypes = WashServiceType::with('prices')->get();
        $changes = 0;

        DB::transaction(function () use ($request, $vehicleTypes, $serviceTypes, &$changes) {
            foreach ($serviceTypes as $type) {
                foreach ($vehicleTypes as $vehicle) {
                    $cell = $type->prices->firstWhere('vehicle_type_id', $vehicle->id);

                    // "Otro" no tiene precio fijo: solo se marca si se ofrece (casilla).
                    $key = $type->is_custom
                        ? "offered.{$type->id}.{$vehicle->id}"
                        : "prices.{$type->id}.{$vehicle->id}";

                    if (! $request->has($key)) {
                        continue; // celda que no venía en el formulario
                    }

                    $price = $type->is_custom ? null : $request->input($key);
                    $offered = $type->is_custom
                        ? $request->boolean($key)
                        : $price !== null && $price !== '';

                    if (! $cell && ! $offered) {
                        continue;
                    }

                    $cell ??= new WashService([
                        'wash_service_type_id' => $type->id,
                        'vehicle_type_id'      => $vehicle->id,
                        'name'                 => $type->name,
                        'is_custom'            => $type->is_custom,
                    ]);

                    $cell->is_active = $offered;
                    if ($offered && ! $type->is_custom) {
                        $cell->base_price = $price;
                    }

                    if ($cell->isDirty()) {
                        $cell->save();
                        $changes++;
                    }
                }
            }
        });

        return redirect()->route('admin.catalog.services.index')->with('status', match ($changes) {
            0       => 'No hubo cambios en los precios.',
            1       => 'Se guardó 1 cambio de precio.',
            default => "Se guardaron {$changes} cambios de precio.",
        });
    }

    public function create(): View
    {
        $serviceType = new WashServiceType(['sort_order' => (int) WashServiceType::max('sort_order') + 1]);

        return view('admin.catalog.services.form', compact('serviceType'));
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $serviceType = WashServiceType::create([
            ...$data,
            'is_custom' => $request->boolean('is_custom'),
        ]);

        return redirect()->route('admin.catalog.services.index')
            ->with('status', "Servicio «{$serviceType->name}» creado. Ponle precio para cada vehículo y guarda.");
    }

    public function edit(WashServiceType $serviceType): View
    {
        return view('admin.catalog.services.form', compact('serviceType'));
    }

    public function update(Request $request, WashServiceType $serviceType): RedirectResponse
    {
        // El tipo (precio fijo u "Otro") no se cambia después de creado: cambiaría cómo
        // se cobran los lavados que ya usan este servicio.
        $serviceType->update($this->validated($request, $serviceType));

        return redirect()->route('admin.catalog.services.index')
            ->with('status', "Servicio «{$serviceType->name}» actualizado.");
    }

    public function toggle(WashServiceType $serviceType): RedirectResponse
    {
        $serviceType->update(['is_active' => ! $serviceType->is_active]);

        return back()->with('status', $serviceType->is_active
            ? "«{$serviceType->name}» está activo para los vehículos que tienen precio."
            : "«{$serviceType->name}» se desactivó para todos los vehículos.");
    }

    private function validated(Request $request, ?WashServiceType $serviceType = null): array
    {
        $data = $this->validateForm($request, [
            'name'       => ['required', 'string', 'max:100', $this->uniqueName('wash_service_types', $serviceType?->id)],
            'sort_order' => 'nullable|integer|min:0|max:999',
        ], ['name' => 'nombre', 'sort_order' => 'orden']);

        return [
            'name'       => trim($data['name']),
            'sort_order' => $data['sort_order'] ?? 0,
        ];
    }
}
