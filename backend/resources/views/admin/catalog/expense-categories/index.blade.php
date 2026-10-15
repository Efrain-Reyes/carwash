@extends('admin.layouts.app')

@section('title', 'Categorías de gastos')

@section('actions')
    <a href="{{ route('admin.catalog.expense-categories.create') }}" class="btn btn-primary">
        <x-admin.icon name="plus" class="size-4" />
        <span class="hidden sm:inline">Nueva categoría</span>
        <span class="sm:hidden">Nueva</span>
    </a>
@endsection

@section('content')
    <p class="mb-5 max-w-2xl text-sm text-muted">
        Sirven para agrupar los <a href="{{ route('admin.catalog.expense-items.index') }}" class="font-semibold text-accent-600 hover:underline">artículos de gastos</a>.
        Ej: Productos de limpieza, Servicios públicos, Mantenimiento.
    </p>

    <div class="card max-w-3xl overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead class="text-left text-xs font-semibold tracking-wide text-muted uppercase">
                    <tr class="border-b border-line bg-surface/60">
                        <th class="px-5 py-3">Categoría</th>
                        <th class="px-5 py-3 text-right">Orden</th>
                        <th class="px-5 py-3 text-right">Artículos</th>
                        <th class="px-5 py-3">Estado</th>
                        <th class="px-5 py-3"><span class="sr-only">Acciones</span></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-line">
                    @forelse ($categories as $category)
                        <tr @class(['opacity-60' => ! $category->is_active])>
                            <td class="px-5 py-3.5 font-semibold">{{ $category->name }}</td>
                            <td class="px-5 py-3.5 text-right tabular-nums">{{ $category->sort_order }}</td>
                            <td class="px-5 py-3.5 text-right tabular-nums">
                                <a href="{{ route('admin.catalog.expense-items.index', ['categoria' => $category->id]) }}" class="text-accent-600 hover:underline">{{ $category->items_count }}</a>
                            </td>
                            <td class="px-5 py-3.5"><x-admin.status :active="$category->is_active" /></td>
                            <td class="px-5 py-3.5">
                                <div class="flex justify-end gap-2">
                                    <a href="{{ route('admin.catalog.expense-categories.edit', $category) }}" class="btn btn-secondary px-3 py-2">
                                        <x-admin.icon name="edit" class="size-4" /> Editar
                                    </a>
                                    <x-admin.toggle-form :action="route('admin.catalog.expense-categories.toggle', $category)" :active="$category->is_active" :name="$category->name" />
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="5" class="px-5 py-6 text-center text-muted">Todavía no hay categorías.</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
@endsection
