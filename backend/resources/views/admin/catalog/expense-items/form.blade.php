@extends('admin.layouts.app')

@php $editing = $item->exists; @endphp

@section('title', $editing ? 'Editar artículo' : 'Nuevo artículo')

@section('content')
    <x-admin.back :href="route('admin.catalog.expense-items.index')">Volver a artículos de gastos</x-admin.back>

    @if ($categories->isEmpty())
        <div class="card max-w-2xl p-6 text-sm text-muted">
            Primero crea una <a href="{{ route('admin.catalog.expense-categories.create') }}" class="font-semibold text-accent-600 hover:underline">categoría de gastos</a>.
        </div>
    @else
        <form method="POST" action="{{ $editing ? route('admin.catalog.expense-items.update', $item) : route('admin.catalog.expense-items.store') }}" class="card max-w-2xl space-y-6 p-6">
            @csrf
            @if ($editing) @method('PUT') @endif

            <div class="grid gap-5 sm:grid-cols-2">
                <x-admin.field name="name" label="Nombre" class="sm:col-span-2">
                    <input id="name" name="name" type="text" value="{{ old('name', $item->name) }}" required maxlength="150" class="field">
                </x-admin.field>

                <x-admin.field name="expense_category_id" label="Categoría" class="sm:col-span-2">
                    <select id="expense_category_id" name="expense_category_id" required class="field">
                        <option value="">Selecciona…</option>
                        @foreach ($categories as $category)
                            <option value="{{ $category->id }}" @selected((int) old('expense_category_id', $item->expense_category_id) === $category->id)>
                                {{ $category->name }}{{ $category->is_active ? '' : ' (inactiva)' }}
                            </option>
                        @endforeach
                    </select>
                </x-admin.field>

                <x-admin.field name="base_price" label="Precio de referencia (opcional)" hint="Se puede cambiar en cada compra.">
                    <div class="relative">
                        <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-muted">L</span>
                        <input id="base_price" name="base_price" type="number" min="0" step="0.01" inputmode="decimal" value="{{ old('base_price', $item->base_price) }}" class="field pl-7">
                    </div>
                </x-admin.field>

                <x-admin.field name="tax_rate" label="Impuesto (%)" hint="Ej: 15 para ISV, 0 si no aplica.">
                    <input id="tax_rate" name="tax_rate" type="number" min="0" max="100" step="0.01" inputmode="decimal" value="{{ old('tax_rate', $item->tax_rate) }}" class="field">
                </x-admin.field>
            </div>

            <div>
                <input type="hidden" name="is_active" value="0">
                <label class="inline-flex items-center gap-3 rounded-xl border border-line px-4 py-2.5 text-sm font-semibold">
                    <input type="checkbox" name="is_active" value="1" class="size-4 rounded border-line" @checked(old('is_active', $item->is_active))>
                    Activo
                </label>
            </div>

            <div class="flex justify-end gap-3 border-t border-line pt-5">
                <a href="{{ route('admin.catalog.expense-items.index') }}" class="btn btn-secondary">Cancelar</a>
                <button type="submit" class="btn btn-primary">{{ $editing ? 'Guardar cambios' : 'Crear artículo' }}</button>
            </div>
        </form>
    @endif
@endsection
