@extends('admin.layouts.app')

@use('App\Support\Format')

@section('title', 'Inicio')

@section('content')
    @php
        $today = $todayReport['resumen'];
        $month = $monthReport['resumen'];
        $services = array_slice($monthReport['lavados']['por_servicio'], 0, 6);
        $monthName = now()->locale('es')->isoFormat('MMMM');

        $stats = [
            ['label' => 'Lavados hoy', 'value' => $todayReport['lavados']['cantidad'], 'hint' => Format::money($today['ingresos_lavados']).' en ingresos'],
            ['label' => "Ingresos de {$monthName}", 'value' => Format::money($month['ingresos_lavados']), 'hint' => $monthReport['lavados']['cantidad'].' lavados'],
            ['label' => "Gastos de {$monthName}", 'value' => Format::money($month['total_gastos']), 'hint' => 'Sin contar sueldos'],
            ['label' => "Utilidad de {$monthName}", 'value' => Format::money($month['utilidad_operativa']), 'hint' => 'Ingresos − gastos − sueldos', 'tone' => $month['utilidad_operativa'] < 0 ? 'bad' : 'ok'],
        ];
    @endphp

    <p class="mb-5 text-sm text-muted first-letter:uppercase">{{ now()->locale('es')->isoFormat('dddd D [de] MMMM [de] YYYY') }}</p>

    <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        @foreach ($stats as $stat)
            <div class="card p-5">
                <p class="text-sm font-medium text-muted">{{ $stat['label'] }}</p>
                <p @class([
                    'mt-2 text-2xl font-extrabold tracking-tight tabular-nums',
                    'text-bad-fg' => ($stat['tone'] ?? null) === 'bad',
                ])>{{ $stat['value'] }}</p>
                <p class="mt-1 text-xs text-muted">{{ $stat['hint'] }}</p>
            </div>
        @endforeach
    </div>

    <div class="mt-6 grid gap-6 lg:grid-cols-5">
        {{-- Caja --}}
        <section class="card self-start p-5 lg:col-span-2">
            <div class="flex items-center justify-between">
                <h2 class="font-bold">Caja</h2>
                @if ($openSession)
                    <span class="badge bg-ok-bg text-ok-fg"><span class="size-1.5 rounded-full bg-ok-fg"></span>Abierta</span>
                @else
                    <span class="badge bg-surface-2 text-muted">Cerrada</span>
                @endif
            </div>

            @if ($openSession)
                <p class="mt-1 text-sm text-muted">
                    Abierta {{ Format::dateTime($openSession->opened_at) }}
                    @if ($openSession->openedBy) por {{ $openSession->openedBy->name }} @endif
                </p>
                @if ($cash['pending_closure'])
                    <p class="mt-3 rounded-xl bg-warn-bg px-3 py-2 text-sm font-medium text-warn-fg">Esta caja viene de días anteriores y está pendiente de cierre.</p>
                @endif
                <dl class="mt-4 space-y-2.5 text-sm">
                    <div class="flex justify-between"><dt class="text-muted">Monto de apertura</dt><dd class="font-semibold tabular-nums">{{ Format::money($openSession->opening_amount) }}</dd></div>
                    <div class="flex justify-between"><dt class="text-muted">Movimiento desde la apertura</dt><dd class="font-semibold tabular-nums">{{ Format::money($cash['movement']) }}</dd></div>
                    <div class="flex justify-between border-t border-line pt-2.5"><dt class="font-semibold">Efectivo esperado</dt><dd class="font-extrabold tabular-nums">{{ Format::money($cash['expected']) }}</dd></div>
                </dl>
            @else
                <p class="mt-3 text-sm text-muted">No hay una caja abierta en este momento.</p>
            @endif
        </section>

        {{-- Servicios del mes --}}
        <section class="card overflow-hidden lg:col-span-3">
            <h2 class="px-5 pt-5 font-bold">Servicios más vendidos en {{ $monthName }}</h2>
            @if ($services === [])
                <p class="px-5 pt-3 pb-5 text-sm text-muted">Todavía no hay lavados este mes.</p>
            @else
                <div class="mt-3 overflow-x-auto">
                    <table class="w-full text-sm">
                        <thead class="text-left text-xs font-semibold tracking-wide text-muted uppercase">
                            <tr class="border-b border-line">
                                <th class="px-5 py-2.5">Servicio</th>
                                <th class="px-5 py-2.5 text-right">Cantidad</th>
                                <th class="px-5 py-2.5 text-right">Total</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                            @foreach ($services as $row)
                                <tr>
                                    <td class="px-5 py-3">
                                        <p class="font-semibold">{{ $row['servicio'] }}</p>
                                        <p class="text-xs text-muted">{{ $row['vehiculo'] }}</p>
                                    </td>
                                    <td class="px-5 py-3 text-right tabular-nums">{{ $row['cantidad'] }}</td>
                                    <td class="px-5 py-3 text-right font-semibold tabular-nums">{{ Format::money($row['total']) }}</td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </section>
    </div>

    {{-- Actividad reciente --}}
    <section class="card mt-6">
        <div class="flex items-center justify-between px-5 pt-5">
            <h2 class="font-bold">Actividad reciente</h2>
            <a href="{{ route('admin.audit.index') }}" class="inline-flex items-center gap-1 text-sm font-semibold text-accent-600 hover:underline">
                Ver bitácora <x-admin.icon name="arrow" class="size-4" />
            </a>
        </div>
        @if ($recentActivity->isEmpty())
            <p class="px-5 pt-3 pb-5 text-sm text-muted">Todavía no hay actividad registrada.</p>
        @else
            <ul class="mt-3 divide-y divide-line">
                @foreach ($recentActivity as $log)
                    <li class="flex flex-wrap items-center gap-x-3 gap-y-1 px-5 py-3 text-sm">
                        <span class="font-semibold">{{ $log->user?->name ?? 'Sistema' }}</span>
                        <span class="text-muted">{{ mb_strtolower($log->eventLabel()) }}</span>
                        @if ($log->auditable_type && $log->event !== 'login')
                            <span>{{ $log->subjectLabel() }} <span class="text-muted">#{{ $log->auditable_id }}</span></span>
                        @endif
                        <span class="ml-auto text-xs text-muted">{{ Format::relative($log->created_at) }}</span>
                    </li>
                @endforeach
            </ul>
        @endif
    </section>
@endsection
