@extends('admin.layouts.app')

@use('App\Models\AuditLog')
@use('App\Support\Format')

@section('title', 'Bitácora')

@section('content')
    @php
        $hasFilters = collect($filters)->filter()->isNotEmpty();
        $eventTones = [
            'created' => 'bg-ok-bg text-ok-fg',
            'updated' => 'bg-info-bg text-info-fg',
            'deleted' => 'bg-bad-bg text-bad-fg',
            'login'   => 'bg-surface-2 text-ink',
        ];
    @endphp

    <p class="mb-5 max-w-2xl text-sm text-muted">
        Registro de quién creó o cambió algo, cuándo y desde dónde (app o panel). Los registros de la bitácora no se pueden editar ni borrar.
    </p>

    {{-- Filtros --}}
    <form method="GET" action="{{ route('admin.audit.index') }}" class="card mb-6 p-5" x-data="{ open: {{ $hasFilters ? 'true' : 'false' }} }">
        <button type="button" class="flex w-full items-center gap-2 text-sm font-bold sm:hidden" @click="open = !open" :aria-expanded="open">
            <x-admin.icon name="filter" class="size-4" /> Filtros
            @if ($hasFilters) <span class="badge bg-info-bg text-info-fg">activos</span> @endif
            <x-admin.icon name="chevron" class="ml-auto size-4 transition" ::class="open && 'rotate-180'" />
        </button>

        <div class="mt-4 hidden gap-4 sm:mt-0 sm:grid sm:grid-cols-2 lg:grid-cols-6" :class="open && 'grid!'">
            <div class="lg:col-span-2">
                <label for="user_id" class="field-label">Usuario</label>
                <select id="user_id" name="user_id" class="field">
                    <option value="">Todos</option>
                    @foreach ($users as $u)
                        <option value="{{ $u->id }}" @selected(($filters['user_id'] ?? '') == $u->id)>{{ $u->name }}</option>
                    @endforeach
                </select>
            </div>
            <div class="lg:col-span-2">
                <label for="module" class="field-label">Módulo</label>
                <select id="module" name="module" class="field">
                    <option value="">Todos</option>
                    @foreach ($modules->sortBy('label') as $key => $module)
                        <option value="{{ $key }}" @selected(($filters['module'] ?? '') === $key)>{{ $module['label'] }}</option>
                    @endforeach
                </select>
            </div>
            <div>
                <label for="event" class="field-label">Acción</label>
                <select id="event" name="event" class="field">
                    <option value="">Todas</option>
                    @foreach (AuditLog::EVENTS as $value => $label)
                        <option value="{{ $value }}" @selected(($filters['event'] ?? '') === $value)>{{ $label }}</option>
                    @endforeach
                </select>
            </div>
            <div>
                <label for="source" class="field-label">Origen</label>
                <select id="source" name="source" class="field">
                    <option value="">Todos</option>
                    @foreach (AuditLog::SOURCES as $value => $label)
                        <option value="{{ $value }}" @selected(($filters['source'] ?? '') === $value)>{{ $label }}</option>
                    @endforeach
                </select>
            </div>
            <div class="lg:col-span-2">
                <label for="date_from" class="field-label">Desde</label>
                <input id="date_from" name="date_from" type="date" value="{{ $filters['date_from'] ?? '' }}" class="field">
            </div>
            <div class="lg:col-span-2">
                <label for="date_to" class="field-label">Hasta</label>
                <input id="date_to" name="date_to" type="date" value="{{ $filters['date_to'] ?? '' }}" class="field">
            </div>
            <div class="flex items-end gap-2 sm:col-span-2">
                <button type="submit" class="btn btn-primary flex-1">Filtrar</button>
                @if ($hasFilters)
                    <a href="{{ route('admin.audit.index') }}" class="btn btn-secondary">Limpiar</a>
                @endif
            </div>
        </div>
    </form>

    {{-- Registros --}}
    <div class="card overflow-hidden">
        @if ($logs->isEmpty())
            <p class="p-6 text-center text-sm text-muted">
                {{ $hasFilters ? 'No hay registros con esos filtros.' : 'Todavía no hay actividad registrada.' }}
            </p>
        @else
            <ul class="divide-y divide-line">
                @foreach ($logs as $log)
                    @php $changes = $log->changes(); @endphp
                    <li x-data="{ open: false }">
                        <div class="flex flex-wrap items-center gap-x-3 gap-y-1.5 px-5 py-3.5 text-sm">
                            <span class="w-full text-xs whitespace-nowrap text-muted tabular-nums sm:w-48 sm:text-sm" title="{{ $log->created_at }}">{{ Format::dateTime($log->created_at) }}</span>
                            <span class="font-semibold">{{ $log->user?->name ?? 'Sistema' }}</span>
                            <span class="badge {{ $eventTones[$log->event] ?? 'bg-surface-2 text-ink' }}">{{ $log->eventLabel() }}</span>
                            @if ($log->auditable_type && $log->event !== 'login')
                                <span><span class="first-letter:uppercase inline-block">{{ $log->subjectLabel() }}</span> <span class="text-muted">#{{ $log->auditable_id }}</span></span>
                            @endif
                            <span class="text-xs text-muted">· {{ $log->sourceLabel() }}</span>

                            @if ($changes !== [])
                                <button type="button" class="ml-auto inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-semibold text-accent-600 hover:bg-info-bg" @click="open = !open" :aria-expanded="open">
                                    {{ count($changes) }} {{ count($changes) === 1 ? 'campo' : 'campos' }}
                                    <x-admin.icon name="chevron" class="size-3.5 transition" ::class="open && 'rotate-180'" />
                                </button>
                            @endif
                        </div>

                        @if ($changes !== [])
                            <div x-show="open" x-cloak x-transition.opacity class="px-5 pb-4">
                                <div class="overflow-x-auto rounded-xl border border-line">
                                    <table class="w-full text-sm">
                                        <thead class="bg-surface text-left text-xs font-semibold text-muted">
                                            <tr>
                                                <th class="px-3 py-2">Campo</th>
                                                @if ($log->event !== 'created') <th class="px-3 py-2">Antes</th> @endif
                                                @if ($log->event !== 'deleted') <th class="px-3 py-2">{{ $log->event === 'created' ? 'Valor' : 'Después' }}</th> @endif
                                            </tr>
                                        </thead>
                                        <tbody class="divide-y divide-line">
                                            @foreach ($changes as $change)
                                                <tr>
                                                    <td class="px-3 py-2 font-medium whitespace-nowrap">{{ AuditLog::fieldLabel($change['field']) }}</td>
                                                    @if ($log->event !== 'created')
                                                        <td class="px-3 py-2 break-all text-muted">{{ AuditLog::formatValue($change['field'], $change['old']) }}</td>
                                                    @endif
                                                    @if ($log->event !== 'deleted')
                                                        <td class="px-3 py-2 break-all">{{ AuditLog::formatValue($change['field'], $change['new']) }}</td>
                                                    @endif
                                                </tr>
                                            @endforeach
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        @endif
                    </li>
                @endforeach
            </ul>

            {{ $logs->links('admin.partials.pagination') }}
        @endif
    </div>
@endsection
