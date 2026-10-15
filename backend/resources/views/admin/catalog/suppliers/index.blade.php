@extends('admin.layouts.app')

@section('title', 'Proveedores')

@section('actions')
    <a href="{{ route('admin.catalog.suppliers.create') }}" class="btn btn-primary">
        <x-admin.icon name="plus" class="size-4" />
        <span class="hidden sm:inline">Nuevo proveedor</span>
        <span class="sm:hidden">Nuevo</span>
    </a>
@endsection

@section('content')
    <form method="GET" action="{{ route('admin.catalog.suppliers.index') }}" class="mb-5 flex max-w-md gap-2">
        <div class="relative flex-1">
            <x-admin.icon name="search" class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted" />
            <input type="search" name="buscar" value="{{ $search }}" placeholder="Buscar por nombre o contacto" aria-label="Buscar proveedor" class="field pl-9">
        </div>
        <button type="submit" class="btn btn-secondary">Buscar</button>
    </form>

    <div class="card overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead class="text-left text-xs font-semibold tracking-wide text-muted uppercase">
                    <tr class="border-b border-line bg-surface/60">
                        <th class="px-5 py-3">Proveedor</th>
                        <th class="px-5 py-3">Contacto</th>
                        <th class="px-5 py-3 text-right">Gastos</th>
                        <th class="px-5 py-3">Estado</th>
                        <th class="px-5 py-3"><span class="sr-only">Acciones</span></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-line">
                    @forelse ($suppliers as $supplier)
                        <tr @class(['opacity-60' => ! $supplier->is_active])>
                            <td class="px-5 py-3.5 font-semibold">{{ $supplier->name }}</td>
                            <td class="px-5 py-3.5 text-muted">{{ $supplier->contact ?: '—' }}</td>
                            <td class="px-5 py-3.5 text-right tabular-nums">{{ number_format($supplier->expenses_count) }}</td>
                            <td class="px-5 py-3.5"><x-admin.status :active="$supplier->is_active" /></td>
                            <td class="px-5 py-3.5">
                                <div class="flex justify-end gap-2">
                                    <a href="{{ route('admin.catalog.suppliers.edit', $supplier) }}" class="btn btn-secondary px-3 py-2">
                                        <x-admin.icon name="edit" class="size-4" /> Editar
                                    </a>
                                    <x-admin.toggle-form :action="route('admin.catalog.suppliers.toggle', $supplier)" :active="$supplier->is_active" :name="$supplier->name" />
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="5" class="px-5 py-6 text-center text-muted">{{ $search !== '' ? 'Ningún proveedor coincide con la búsqueda.' : 'Todavía no hay proveedores.' }}</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
@endsection
