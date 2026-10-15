<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Admin\Concerns\ValidatesInSpanish;
use App\Http\Controllers\Controller;
use App\Models\VehicleType;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class VehicleTypeController extends Controller
{
    use ValidatesInSpanish;

    public function index(): View
    {
        $vehicleTypes = VehicleType::ordered()
            ->withCount([
                'washServices as prices_count' => fn ($q) => $q->where('is_active', true),
                'washes',
            ])
            ->get();

        return view('admin.catalog.vehicles.index', compact('vehicleTypes'));
    }

    public function create(): View
    {
        $vehicleType = new VehicleType([
            'is_active'  => true,
            'sort_order' => (int) VehicleType::max('sort_order') + 1,
        ]);

        return view('admin.catalog.vehicles.form', compact('vehicleType'));
    }

    public function store(Request $request): RedirectResponse
    {
        $vehicleType = VehicleType::create($this->validated($request));

        return redirect()->route('admin.catalog.services.index')
            ->with('status', "Tipo de vehículo «{$vehicleType->name}» creado. Ahora ponle precio a sus servicios.");
    }

    public function edit(VehicleType $vehicleType): View
    {
        return view('admin.catalog.vehicles.form', compact('vehicleType'));
    }

    public function update(Request $request, VehicleType $vehicleType): RedirectResponse
    {
        $vehicleType->update($this->validated($request, $vehicleType));

        return redirect()->route('admin.catalog.vehicles.index')
            ->with('status', "Tipo de vehículo «{$vehicleType->name}» actualizado.");
    }

    public function toggle(VehicleType $vehicleType): RedirectResponse
    {
        $vehicleType->update(['is_active' => ! $vehicleType->is_active]);

        return back()->with('status', $vehicleType->is_active
            ? "«{$vehicleType->name}» está activo y vuelve a aparecer en la app."
            : "«{$vehicleType->name}» se desactivó y ya no aparece en la app.");
    }

    private function validated(Request $request, ?VehicleType $vehicleType = null): array
    {
        $data = $this->validateForm($request, [
            'name'       => ['required', 'string', 'max:100', $this->uniqueName('vehicle_types', $vehicleType?->id)],
            'icon'       => ['required', Rule::in(array_keys(VehicleType::ICONS))],
            'sort_order' => 'nullable|integer|min:0|max:999',
            'is_active'  => 'boolean',
        ], ['name' => 'nombre', 'icon' => 'icono', 'sort_order' => 'orden']);

        return [
            ...$data,
            'sort_order' => $data['sort_order'] ?? 0,
            'is_active'  => $request->boolean('is_active'),
        ];
    }
}
