@extends('admin.layouts.app')

@php $editing = $category->exists; @endphp

@section('title', $editing ? 'Editar categoría' : 'Nueva categoría')

@section('content')
    <x-admin.back :href="route('admin.catalog.expense-categories.index')">Volver a categorías</x-admin.back>

    <form method="POST" action="{{ $editing ? route('admin.catalog.expense-categories.update', $category) : route('admin.catalog.expense-categories.store') }}" class="card max-w-2xl space-y-6 p-6">
        @csrf
        @if ($editing) @method('PUT') @endif

        <div class="grid gap-5 sm:grid-cols-3">
            <x-admin.field name="name" label="Nombre" class="sm:col-span-2">
                <input id="name" name="name" type="text" value="{{ old('name', $category->name) }}" required maxlength="100" class="field">
            </x-admin.field>

            <x-admin.field name="sort_order" label="Orden">
                <input id="sort_order" name="sort_order" type="number" min="0" max="999" value="{{ old('sort_order', $category->sort_order) }}" class="field">
            </x-admin.field>
        </div>

        <div>
            <input type="hidden" name="is_active" value="0">
            <label class="inline-flex items-center gap-3 rounded-xl border border-line px-4 py-2.5 text-sm font-semibold">
                <input type="checkbox" name="is_active" value="1" class="size-4 rounded border-line" @checked(old('is_active', $category->is_active))>
                Activa
            </label>
        </div>

        <div class="flex justify-end gap-3 border-t border-line pt-5">
            <a href="{{ route('admin.catalog.expense-categories.index') }}" class="btn btn-secondary">Cancelar</a>
            <button type="submit" class="btn btn-primary">{{ $editing ? 'Guardar cambios' : 'Crear categoría' }}</button>
        </div>
    </form>
@endsection
