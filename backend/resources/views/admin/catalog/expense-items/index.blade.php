@extends('admin.layouts.app')

@use('App\Support\Format')

@section('title', 'Artículos de gastos')

@section('actions')
    <a href="{{ route('admin.catalog.expense-items.create') }}" class="btn btn-primary">
        <x-admin.icon name="plus" class="size-4" />
        <span class="hidden sm:inline">Nuevo artículo</span>
        <span class="sm:hidden">Nuevo</span>
    </a>
@endsection

@section('content')
    <p class="mb-5 max-w-2xl text-sm text-muted">
        Lo que se compra seguido (jabón, cera, agua, luz...) con un precio de referencia e impuesto.
    </p>

    <form method="GET" action="{{ route('admin.catalog.expense-items.index') }}" class="mb-5 grid max-w-2xl gap-2 sm:grid-cols-[1fr_14rem_auto]">
        <div class="relative">
            <x-admin.icon name="search" class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted" />
            <input type="search" name="buscar" value="{{ $search }}" placeholder="Buscar artículo" aria-label="Buscar artículo" class="field pl-9">
        </div>
        <select name="categoria" class="field" aria-label="Categoría">
            <option value="">Todas las categorías</option>
            @foreach ($categories as $category)
                <option value="{{ $category->id }}" @selected($categoryId === $category->id)>{{ $category->name }}</option>
            @endforeach
        </select>
        <button type="submit" class="btn btn-secondary">Filtrar</button>
    </form>

    <div class="card overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead class="text-left text-xs font-semibold tracking-wide text-muted uppercase">
                    <tr class="border-b border-line bg-surface/60">
                        <th class="px-5 py-3">Artículo</th>
                        <th class="px-5 py-3">Categoría</th>
                        <th class="px-5 py-3 text-right">Precio ref.</th>
                        <th class="px-5 py-3 text-right">Impuesto</th>
                        <th class="px-5 py-3">Estado</th>
                        <th class="px-5 py-3"><span class="sr-only">Acciones</span></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-line">
                    @forelse ($items as $item)
                        <tr @class(['opacity-60' => ! $item->is_active])>
                            <td class="px-5 py-3.5 font-semibold">{{ $item->name }}</td>
                            <td class="px-5 py-3.5">{{ $item->category?->name ?? '—' }}</td>
                            <td class="px-5 py-3.5 text-right tabular-nums">{{ $item->base_price !== null ? Format::money($item->base_price) : '—' }}</td>
                            <td class="px-5 py-3.5 text-right tabular-nums">{{ rtrim(rtrim(number_format((float) $item->tax_rate, 2), '0'), '.') }}%</td>
                            <td class="px-5 py-3.5"><x-admin.status :active="$item->is_active" /></td>
                            <td class="px-5 py-3.5">
                                <div class="flex justify-end gap-2">
                                    <a href="{{ route('admin.catalog.expense-items.edit', $item) }}" class="btn btn-secondary px-3 py-2">
                                        <x-admin.icon name="edit" class="size-4" /> Editar
                                    </a>
                                    <x-admin.toggle-form :action="route('admin.catalog.expense-items.toggle', $item)" :active="$item->is_active" :name="$item->name" />
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-5 py-8 text-center text-muted">
                                @if ($search !== '' || $categoryId)
                                    Ningún artículo coincide con el filtro.
                                @else
                                    Todavía no hay artículos. <a href="{{ route('admin.catalog.expense-items.create') }}" class="font-semibold text-accent-600 hover:underline">Crea el primero</a>.
                                @endif
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
@endsection
