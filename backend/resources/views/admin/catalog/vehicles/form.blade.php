@extends('admin.layouts.app')

@use('App\Models\VehicleType')

@php $editing = $vehicleType->exists; @endphp

@section('title', $editing ? 'Editar tipo de vehículo' : 'Nuevo tipo de vehículo')

@section('content')
    <x-admin.back :href="route('admin.catalog.vehicles.index')">Volver a tipos de vehículo</x-admin.back>

    <form method="POST" action="{{ $editing ? route('admin.catalog.vehicles.update', $vehicleType) : route('admin.catalog.vehicles.store') }}" class="card max-w-2xl space-y-6 p-6">
        @csrf
        @if ($editing) @method('PUT') @endif

        <div class="grid gap-5 sm:grid-cols-3">
            <x-admin.field name="name" label="Nombre" class="sm:col-span-2" hint="Así lo verá el operador en la app. Ej: Carro, Pick-up, Moto.">
                <input id="name" name="name" type="text" value="{{ old('name', $vehicleType->name) }}" required maxlength="100" class="field">
            </x-admin.field>

            <x-admin.field name="sort_order" label="Orden" hint="Menor = aparece primero.">
                <input id="sort_order" name="sort_order" type="number" min="0" max="999" value="{{ old('sort_order', $vehicleType->sort_order) }}" class="field">
            </x-admin.field>
        </div>

        <fieldset>
            <legend class="field-label">Icono</legend>
            @php $currentIcon = old('icon', $vehicleType->icon ?? 'car'); @endphp
            <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
                @foreach (VehicleType::ICONS as $key => $icon)
                    <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2.5 text-sm has-checked:border-accent-500 has-checked:bg-info-bg/50">
                        <input type="radio" name="icon" value="{{ $key }}" class="sr-only" @checked($currentIcon === $key)>
                        <span class="text-2xl" aria-hidden="true">{{ $icon['emoji'] }}</span>
                        <span class="font-medium">{{ $icon['label'] }}</span>
                    </label>
                @endforeach
            </div>
            @error('icon') <p class="field-error">{{ $message }}</p> @enderror
        </fieldset>

        <div>
            <input type="hidden" name="is_active" value="0">
            <label class="inline-flex items-center gap-3 rounded-xl border border-line px-4 py-2.5 text-sm font-semibold">
                <input type="checkbox" name="is_active" value="1" class="size-4 rounded border-line" @checked(old('is_active', $vehicleType->is_active))>
                Activo (aparece en la app)
            </label>
        </div>

        <div class="flex justify-end gap-3 border-t border-line pt-5">
            <a href="{{ route('admin.catalog.vehicles.index') }}" class="btn btn-secondary">Cancelar</a>
            <button type="submit" class="btn btn-primary">{{ $editing ? 'Guardar cambios' : 'Crear tipo de vehículo' }}</button>
        </div>
    </form>
@endsection
