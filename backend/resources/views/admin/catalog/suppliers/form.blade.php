@extends('admin.layouts.app')

@php $editing = $supplier->exists; @endphp

@section('title', $editing ? 'Editar proveedor' : 'Nuevo proveedor')

@section('content')
    <x-admin.back :href="route('admin.catalog.suppliers.index')">Volver a proveedores</x-admin.back>

    <form method="POST" action="{{ $editing ? route('admin.catalog.suppliers.update', $supplier) : route('admin.catalog.suppliers.store') }}" class="card max-w-2xl space-y-6 p-6">
        @csrf
        @if ($editing) @method('PUT') @endif

        <x-admin.field name="name" label="Nombre">
            <input id="name" name="name" type="text" value="{{ old('name', $supplier->name) }}" required maxlength="150" class="field">
        </x-admin.field>

        <x-admin.field name="contact" label="Contacto (opcional)" hint="Teléfono, correo o nombre de la persona.">
            <input id="contact" name="contact" type="text" value="{{ old('contact', $supplier->contact) }}" maxlength="150" class="field">
        </x-admin.field>

        <div>
            <input type="hidden" name="is_active" value="0">
            <label class="inline-flex items-center gap-3 rounded-xl border border-line px-4 py-2.5 text-sm font-semibold">
                <input type="checkbox" name="is_active" value="1" class="size-4 rounded border-line" @checked(old('is_active', $supplier->is_active))>
                Activo
            </label>
        </div>

        <div class="flex justify-end gap-3 border-t border-line pt-5">
            <a href="{{ route('admin.catalog.suppliers.index') }}" class="btn btn-secondary">Cancelar</a>
            <button type="submit" class="btn btn-primary">{{ $editing ? 'Guardar cambios' : 'Crear proveedor' }}</button>
        </div>
    </form>
@endsection
