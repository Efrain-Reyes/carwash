@extends('admin.layouts.app')

@section('title', 'Servicios y precios')

@section('actions')
    <a href="{{ route('admin.catalog.services.create') }}" class="btn btn-primary">
        <x-admin.icon name="plus" class="size-4" />
        <span class="hidden sm:inline">Nuevo servicio</span>
        <span class="sm:hidden">Nuevo</span>
    </a>
@endsection

@section('content')
    <p class="mb-5 max-w-3xl text-sm text-muted">
        Cada servicio se define una sola vez. Escribe su precio para cada tipo de vehículo y deja la casilla
        <strong class="font-semibold text-ink">vacía si no se ofrece</strong>. Los cambios aplican a los lavados nuevos;
        los que ya se registraron conservan el precio con que se cobraron.
    </p>

    @if ($serviceTypes->isEmpty() || $vehicleTypes->isEmpty())
        <div class="card p-6 text-center text-sm text-muted">
            Primero crea al menos un <a href="{{ route('admin.catalog.vehicles.create') }}" class="font-semibold text-accent-600 hover:underline">tipo de vehículo</a>
            y un <a href="{{ route('admin.catalog.services.create') }}" class="font-semibold text-accent-600 hover:underline">servicio</a>.
        </div>
    @else
        <form method="POST" action="{{ route('admin.catalog.services.prices') }}" id="prices-form">
            @csrf
            @method('PUT')

            @if ($errors->any())
                <div class="mb-4 rounded-xl border border-bad-fg/15 bg-bad-bg px-4 py-3 text-sm font-medium text-bad-fg" role="alert">
                    Revisa los precios marcados en rojo: deben ser números de 0 en adelante.
                </div>
            @endif

            @if ($vehicleTypes->count() > 1)
                <p class="mb-2 text-xs font-medium text-muted sm:hidden">Desliza la tabla a la izquierda para ver todos los vehículos →</p>
            @endif

            <div class="card overflow-hidden">
                <div class="overflow-x-auto">
                    <table class="w-full text-sm">
                        <thead>
                            <tr class="border-b border-line bg-surface/60">
                                <th class="sticky left-0 z-10 min-w-40 bg-surface px-4 py-3 sm:min-w-56 sm:px-5 text-left text-xs font-semibold tracking-wide text-muted uppercase">Servicio</th>
                                @foreach ($vehicleTypes as $vehicle)
                                    <th @class(['min-w-36 px-3 py-3 text-left', 'opacity-50' => ! $vehicle->is_active])>
                                        <span class="flex items-center gap-2 font-semibold">
                                            <span class="text-lg" aria-hidden="true">{{ $vehicle->emoji() }}</span>
                                            {{ $vehicle->name }}
                                        </span>
                                        @unless ($vehicle->is_active)
                                            <span class="text-xs font-medium text-muted">inactivo en la app</span>
                                        @endunless
                                    </th>
                                @endforeach
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                            @foreach ($serviceTypes as $type)
                                <tr @class(['bg-surface/50' => ! $type->is_active])>
                                    <td class="sticky left-0 z-10 bg-white px-4 py-3.5 align-top shadow-[1px_0_0_var(--color-line)] sm:px-5">
                                        <div @class(['opacity-60' => ! $type->is_active])>
                                            <p class="font-semibold">{{ $type->name }}</p>
                                            <div class="mt-1 flex flex-wrap gap-1.5">
                                                @if ($type->is_custom)
                                                    <span class="badge bg-warn-bg text-warn-fg">Precio libre</span>
                                                @endif
                                                @unless ($type->is_active)
                                                    <span class="badge bg-bad-bg text-bad-fg">Inactivo</span>
                                                @endunless
                                            </div>
                                        </div>
                                        <div class="mt-2 flex gap-3 text-xs font-semibold">
                                            <a href="{{ route('admin.catalog.services.edit', $type) }}" class="text-accent-600 hover:underline">Editar</a>
                                            {{-- Los formularios no se pueden anidar: el botón apunta a un form fuera de la tabla. --}}
                                            <button type="submit" form="toggle-service-{{ $type->id }}"
                                                    onclick="return confirm(@js($type->is_active ? "¿Desactivar «{$type->name}» para todos los vehículos?" : "¿Activar «{$type->name}»?"))"
                                                    @class(['hover:underline', 'text-bad-fg' => $type->is_active, 'text-ok-fg' => ! $type->is_active])>
                                                {{ $type->is_active ? 'Desactivar' : 'Activar' }}
                                            </button>
                                        </div>
                                    </td>

                                    @foreach ($vehicleTypes as $vehicle)
                                        @php
                                            $cell = $matrix[$type->id][$vehicle->id] ?? null;
                                            $offered = $cell?->is_active ?? false;
                                        @endphp
                                        <td class="px-3 py-3.5 align-top">
                                            @if ($type->is_custom)
                                                <input type="hidden" name="offered[{{ $type->id }}][{{ $vehicle->id }}]" value="0">
                                                <label class="inline-flex items-center gap-2 rounded-xl border border-line px-3 py-2 text-sm">
                                                    <input type="checkbox" name="offered[{{ $type->id }}][{{ $vehicle->id }}]" value="1" class="size-4 rounded border-line"
                                                           @checked(old("offered.{$type->id}.{$vehicle->id}", $offered))>
                                                    Se ofrece
                                                </label>
                                            @else
                                                @php
                                                    $key = "prices.{$type->id}.{$vehicle->id}";
                                                    $value = old($key, $offered ? $cell->base_price : '');
                                                @endphp
                                                <div class="relative">
                                                    <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-muted">L</span>
                                                    <input type="number" name="prices[{{ $type->id }}][{{ $vehicle->id }}]" value="{{ $value }}"
                                                           min="0" step="0.01" inputmode="decimal"
                                                           placeholder="{{ $cell && ! $offered && $cell->base_price !== null ? 'antes '.number_format($cell->base_price, 2) : 'No se ofrece' }}"
                                                           aria-label="Precio de {{ $type->name }} para {{ $vehicle->name }}"
                                                           @class(['field pl-7 tabular-nums', 'border-bad-fg' => $errors->has($key)])>
                                                </div>
                                            @endif
                                        </td>
                                    @endforeach
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>

                <div class="flex flex-col gap-3 border-t border-line bg-surface/60 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
                    <p class="text-xs text-muted">Vacío = no se ofrece para ese vehículo. Nada se borra: los lavados viejos mantienen su servicio y precio.</p>
                    <button type="submit" class="btn btn-primary">Guardar precios</button>
                </div>
            </div>
        </form>

        @foreach ($serviceTypes as $type)
            <form method="POST" action="{{ route('admin.catalog.services.toggle', $type) }}" id="toggle-service-{{ $type->id }}" class="hidden">
                @csrf
                @method('PATCH')
            </form>
        @endforeach
    @endif
@endsection
