@extends('admin.layouts.app')

@php $editing = $serviceType->exists; @endphp

@section('title', $editing ? 'Editar servicio' : 'Nuevo servicio')

@section('content')
    <x-admin.back :href="route('admin.catalog.services.index')">Volver a servicios y precios</x-admin.back>

    <form method="POST" action="{{ $editing ? route('admin.catalog.services.update', $serviceType) : route('admin.catalog.services.store') }}" class="card max-w-2xl space-y-6 p-6">
        @csrf
        @if ($editing) @method('PUT') @endif

        <div class="grid gap-5 sm:grid-cols-3">
            <x-admin.field name="name" label="Nombre del servicio" class="sm:col-span-2"
                           :hint="$editing ? 'Al cambiar el nombre se actualiza para todos los vehículos.' : 'Ej: Lavado general, Lavado con motor, Encerado.'">
                <input id="name" name="name" type="text" value="{{ old('name', $serviceType->name) }}" required maxlength="100" class="field">
            </x-admin.field>

            <x-admin.field name="sort_order" label="Orden" hint="Menor = aparece primero en la app.">
                <input id="sort_order" name="sort_order" type="number" min="0" max="999" value="{{ old('sort_order', $serviceType->sort_order) }}" class="field">
            </x-admin.field>
        </div>

        <fieldset>
            <legend class="field-label">¿Cómo se cobra?</legend>
            @if ($editing)
                <p class="rounded-xl bg-surface px-4 py-3 text-sm">
                    {{ $serviceType->is_custom ? 'Precio libre: se escribe el precio y la descripción al registrar el lavado.' : 'Precio fijo por tipo de vehículo, definido en la matriz de precios.' }}
                    <span class="mt-1 block text-xs text-muted">No se puede cambiar porque afectaría cómo se cobran los lavados que ya usan este servicio.</span>
                </p>
            @else
                @php $custom = (bool) old('is_custom', false); @endphp
                <div class="grid gap-3 sm:grid-cols-2">
                    <label class="flex cursor-pointer gap-3 rounded-xl border border-line p-4 has-checked:border-accent-500 has-checked:bg-info-bg/50">
                        <input type="radio" name="is_custom" value="0" class="mt-0.5" @checked(! $custom)>
                        <span>
                            <span class="block text-sm font-semibold">Precio fijo</span>
                            <span class="block text-xs text-muted">Cada vehículo tiene su precio en la matriz.</span>
                        </span>
                    </label>
                    <label class="flex cursor-pointer gap-3 rounded-xl border border-line p-4 has-checked:border-accent-500 has-checked:bg-info-bg/50">
                        <input type="radio" name="is_custom" value="1" class="mt-0.5" @checked($custom)>
                        <span>
                            <span class="block text-sm font-semibold">Precio libre</span>
                            <span class="block text-xs text-muted">Se escribe al registrar el lavado (como «Otro»).</span>
                        </span>
                    </label>
                </div>
            @endif
        </fieldset>

        <div class="flex justify-end gap-3 border-t border-line pt-5">
            <a href="{{ route('admin.catalog.services.index') }}" class="btn btn-secondary">Cancelar</a>
            <button type="submit" class="btn btn-primary">{{ $editing ? 'Guardar cambios' : 'Crear servicio' }}</button>
        </div>
    </form>
@endsection
