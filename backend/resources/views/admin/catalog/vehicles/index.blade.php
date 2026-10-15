@extends('admin.layouts.app')

@section('title', 'Tipos de vehículo')

@section('actions')
    <a href="{{ route('admin.catalog.vehicles.create') }}" class="btn btn-primary">
        <x-admin.icon name="plus" class="size-4" />
        <span class="hidden sm:inline">Nuevo tipo</span>
        <span class="sm:hidden">Nuevo</span>
    </a>
@endsection

@section('content')
    <p class="mb-5 max-w-2xl text-sm text-muted">
        Son las opciones que ve el operador al registrar un lavado, en este orden. Los precios de cada uno se ponen en
        <a href="{{ route('admin.catalog.services.index') }}" class="font-semibold text-accent-600 hover:underline">Servicios y precios</a>.
    </p>

    <div class="card overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead class="text-left text-xs font-semibold tracking-wide text-muted uppercase">
                    <tr class="border-b border-line bg-surface/60">
                        <th class="px-5 py-3">Vehículo</th>
                        <th class="px-5 py-3 text-right">Orden</th>
                        <th class="px-5 py-3 text-right">Servicios con precio</th>
                        <th class="px-5 py-3 text-right">Lavados</th>
                        <th class="px-5 py-3">Estado</th>
                        <th class="px-5 py-3"><span class="sr-only">Acciones</span></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-line">
                    @forelse ($vehicleTypes as $vehicle)
                        <tr @class(['opacity-60' => ! $vehicle->is_active])>
                            <td class="px-5 py-3.5">
                                <span class="flex items-center gap-3 font-semibold">
                                    <span class="grid size-9 place-items-center rounded-xl bg-surface-2 text-xl" aria-hidden="true">{{ $vehicle->emoji() }}</span>
                                    {{ $vehicle->name }}
                                </span>
                            </td>
                            <td class="px-5 py-3.5 text-right tabular-nums">{{ $vehicle->sort_order }}</td>
                            <td class="px-5 py-3.5 text-right tabular-nums">
                                @if ($vehicle->prices_count === 0)
                                    <span class="badge bg-warn-bg text-warn-fg">Sin precios</span>
                                @else
                                    {{ $vehicle->prices_count }}
                                @endif
                            </td>
                            <td class="px-5 py-3.5 text-right tabular-nums">{{ number_format($vehicle->washes_count) }}</td>
                            <td class="px-5 py-3.5"><x-admin.status :active="$vehicle->is_active" /></td>
                            <td class="px-5 py-3.5">
                                <div class="flex justify-end gap-2">
                                    <a href="{{ route('admin.catalog.vehicles.edit', $vehicle) }}" class="btn btn-secondary px-3 py-2">
                                        <x-admin.icon name="edit" class="size-4" /> Editar
                                    </a>
                                    <x-admin.toggle-form :action="route('admin.catalog.vehicles.toggle', $vehicle)" :active="$vehicle->is_active" :name="$vehicle->name" />
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="6" class="px-5 py-6 text-center text-muted">Todavía no hay tipos de vehículo.</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
@endsection
