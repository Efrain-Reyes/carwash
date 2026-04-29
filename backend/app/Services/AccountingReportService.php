<?php

namespace App\Services;

use App\Models\EmployeeAdvance;
use App\Models\EmployeeAdvancePayment;
use App\Models\Expense;
use App\Models\ExpenseItem;
use App\Models\PayrollPayment;
use App\Models\Wash;
use Carbon\CarbonPeriod;
use Illuminate\Support\Carbon;

class AccountingReportService
{
    private Carbon $from;
    private Carbon $to;

    public function generate(string $dateFrom, string $dateTo): array
    {
        $this->setRange($dateFrom, $dateTo);

        $ingresos        = $this->totalIngresos();
        $gastos          = $this->totalGastos();
        $sueldoDevengado = $this->sueldoDevengado();
        $nominaNeta      = $this->nominaNetaPagada();
        $adelantos       = $this->adelantosEntregados();
        $abonos          = $this->abonosRecibidos();

        return [
            'periodo' => [
                'desde' => $this->from->toDateString(),
                'hasta' => $this->to->toDateString(),
            ],

            'resumen' => [
                'ingresos_lavados'              => $ingresos,
                'total_gastos'                  => $gastos,
                'sueldo_devengado'              => $sueldoDevengado,
                'nomina_neta_pagada'            => $nominaNeta,
                'adelantos_entregados'          => $adelantos,
                'abonos_recibidos_trabajadores' => $abonos,
                'utilidad_operativa'            => round($ingresos - $gastos - $sueldoDevengado, 2),
                'flujo_efectivo_estimado'       => round($ingresos - $gastos - $adelantos - $nominaNeta + $abonos, 2),
            ],

            'lavados' => [
                'cantidad'     => $this->cantidadLavados(),
                'por_vehiculo' => $this->statsPorVehiculo(),
                'por_servicio' => $this->statsPorServicio(),
            ],

            'gastos_detalle' => [
                'por_proveedor' => $this->gastosPorProveedor(),
                'por_item'      => $this->gastosPorItem(),
            ],
        ];
    }

    public function timeline(string $dateFrom, string $dateTo): array
    {
        $this->setRange($dateFrom, $dateTo);

        // Timeline diario en zona horaria local: mantiene la misma lógica del
        // resumen contable, pero agrupada por fecha dentro del rango filtrado.
        $ingresos = $this->washTotalsByDate();
        $gastos = $this->expenseTotalsByDate();
        $sueldos = $this->payrollGrossTotalsByDate();
        $nominaNeta = $this->payrollNetTotalsByDate();
        $adelantos = $this->advanceTotalsByDate();
        $abonos = $this->cashAdvancePaymentTotalsByDate();

        $timeline = collect(CarbonPeriod::create($this->from->copy()->startOfDay(), $this->to->copy()->startOfDay()))
            ->map(function (Carbon $date) use ($ingresos, $gastos, $sueldos, $nominaNeta, $adelantos, $abonos) {
                $key = $date->toDateString();
                $dailyIngresos = (float) ($ingresos[$key] ?? 0);
                $dailyGastos = (float) ($gastos[$key] ?? 0);
                $dailySueldos = (float) ($sueldos[$key] ?? 0);
                $dailyNominaNeta = (float) ($nominaNeta[$key] ?? 0);
                $dailyAdelantos = (float) ($adelantos[$key] ?? 0);
                $dailyAbonos = (float) ($abonos[$key] ?? 0);

                return [
                    'fecha' => $key,
                    'ingresos_lavados' => round($dailyIngresos, 2),
                    'gastos' => round($dailyGastos, 2),
                    'utilidad_operativa' => round($dailyIngresos - $dailyGastos - $dailySueldos, 2),
                    'flujo_efectivo_estimado' => round($dailyIngresos - $dailyGastos - $dailyAdelantos - $dailyNominaNeta + $dailyAbonos, 2),
                ];
            })
            ->values()
            ->toArray();

        return [
            'periodo' => [
                'desde' => $this->from->toDateString(),
                'hasta' => $this->to->toDateString(),
            ],
            'timeline' => $timeline,
        ];
    }

    private function setRange(string $dateFrom, string $dateTo): void
    {
        $tz = config('app.timezone');

        $this->from = Carbon::parse($dateFrom, $tz)->startOfDay();
        $this->to   = Carbon::parse($dateTo,   $tz)->endOfDay();
    }

    // ──────────────────────────────────────────────
    // Totales del resumen
    // ──────────────────────────────────────────────

    private function totalIngresos(): float
    {
        return (float) Wash::where('status', 'completado')
            ->whereBetween('registered_at', [$this->from, $this->to])
            ->sum('price');
    }

    private function totalGastos(): float
    {
        return (float) Expense::where('status', 'activo')
            ->whereBetween('expense_date', [$this->from, $this->to])
            ->sum('total');
    }

    private function sueldoDevengado(): float
    {
        return (float) PayrollPayment::where('status', 'pagado')
            ->whereBetween('payment_date', [$this->from, $this->to])
            ->sum('gross_amount');
    }

    private function nominaNetaPagada(): float
    {
        return (float) PayrollPayment::where('status', 'pagado')
            ->whereBetween('payment_date', [$this->from, $this->to])
            ->sum('net_amount');
    }

    private function adelantosEntregados(): float
    {
        return (float) EmployeeAdvance::whereNotIn('status', ['anulado'])
            ->whereBetween('advance_date', [$this->from, $this->to])
            ->sum('amount');
    }

    private function abonosRecibidos(): float
    {
        return (float) EmployeeAdvancePayment::where('payment_type', 'abono_efectivo')
            ->whereBetween('payment_date', [$this->from, $this->to])
            ->sum('amount');
    }

    // ──────────────────────────────────────────────
    // Estadísticas de lavados
    // ──────────────────────────────────────────────

    private function cantidadLavados(): int
    {
        return Wash::where('status', 'completado')
            ->whereBetween('registered_at', [$this->from, $this->to])
            ->count();
    }

    private function statsPorVehiculo(): array
    {
        return Wash::where('status', 'completado')
            ->whereBetween('registered_at', [$this->from, $this->to])
            ->join('vehicle_types', 'washes.vehicle_type_id', '=', 'vehicle_types.id')
            ->selectRaw('vehicle_types.name as tipo, COUNT(*) as cantidad, SUM(washes.price) as total')
            ->groupBy('vehicle_types.id', 'vehicle_types.name')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($r) => [
                'tipo'     => $r->tipo,
                'cantidad' => (int) $r->cantidad,
                'total'    => (float) $r->total,
            ])
            ->toArray();
    }

    private function statsPorServicio(): array
    {
        return Wash::where('status', 'completado')
            ->whereBetween('registered_at', [$this->from, $this->to])
            ->join('wash_services', 'washes.wash_service_id', '=', 'wash_services.id')
            ->join('vehicle_types', 'washes.vehicle_type_id', '=', 'vehicle_types.id')
            ->selectRaw('vehicle_types.name as vehiculo, wash_services.name as servicio, COUNT(*) as cantidad, SUM(washes.price) as total')
            ->groupBy('wash_services.id', 'wash_services.name', 'vehicle_types.id', 'vehicle_types.name')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($r) => [
                'vehiculo' => $r->vehiculo,
                'servicio' => $r->servicio,
                'cantidad' => (int) $r->cantidad,
                'total'    => (float) $r->total,
            ])
            ->toArray();
    }

    // ──────────────────────────────────────────────
    // Detalle de gastos
    // ──────────────────────────────────────────────

    private function gastosPorProveedor(): array
    {
        return Expense::where('status', 'activo')
            ->whereBetween('expense_date', [$this->from, $this->to])
            ->join('expense_suppliers', 'expenses.supplier_id', '=', 'expense_suppliers.id')
            ->selectRaw('expense_suppliers.name as proveedor, COUNT(*) as facturas, SUM(expenses.total) as total')
            ->groupBy('expense_suppliers.id', 'expense_suppliers.name')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($r) => [
                'proveedor' => $r->proveedor,
                'facturas'  => (int) $r->facturas,
                'total'     => (float) $r->total,
            ])
            ->toArray();
    }

    private function gastosPorItem(): array
    {
        return ExpenseItem::join('expenses', 'expense_items.expense_id', '=', 'expenses.id')
            ->where('expenses.status', 'activo')
            ->whereBetween('expenses.expense_date', [$this->from, $this->to])
            ->selectRaw('expense_items.description, SUM(expense_items.quantity) as cantidad, SUM(expense_items.total) as total')
            ->groupBy('expense_items.description')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($r) => [
                'descripcion' => $r->description,
                'cantidad'    => (float) $r->cantidad,
                'total'       => (float) $r->total,
            ])
            ->toArray();
    }

    private function washTotalsByDate(): array
    {
        return Wash::where('status', 'completado')
            ->whereBetween('registered_at', [$this->from, $this->to])
            ->selectRaw('DATE(registered_at) as fecha, SUM(price) as total')
            ->groupBy('fecha')
            ->pluck('total', 'fecha')
            ->map(fn ($value) => (float) $value)
            ->toArray();
    }

    private function expenseTotalsByDate(): array
    {
        return Expense::where('status', 'activo')
            ->whereBetween('expense_date', [$this->from, $this->to])
            ->selectRaw('DATE(expense_date) as fecha, SUM(total) as total')
            ->groupBy('fecha')
            ->pluck('total', 'fecha')
            ->map(fn ($value) => (float) $value)
            ->toArray();
    }

    private function payrollGrossTotalsByDate(): array
    {
        return PayrollPayment::where('status', 'pagado')
            ->whereBetween('payment_date', [$this->from, $this->to])
            ->selectRaw('DATE(payment_date) as fecha, SUM(gross_amount) as total')
            ->groupBy('fecha')
            ->pluck('total', 'fecha')
            ->map(fn ($value) => (float) $value)
            ->toArray();
    }

    private function payrollNetTotalsByDate(): array
    {
        return PayrollPayment::where('status', 'pagado')
            ->whereBetween('payment_date', [$this->from, $this->to])
            ->selectRaw('DATE(payment_date) as fecha, SUM(net_amount) as total')
            ->groupBy('fecha')
            ->pluck('total', 'fecha')
            ->map(fn ($value) => (float) $value)
            ->toArray();
    }

    private function advanceTotalsByDate(): array
    {
        return EmployeeAdvance::whereNotIn('status', ['anulado'])
            ->whereBetween('advance_date', [$this->from, $this->to])
            ->selectRaw('DATE(advance_date) as fecha, SUM(amount) as total')
            ->groupBy('fecha')
            ->pluck('total', 'fecha')
            ->map(fn ($value) => (float) $value)
            ->toArray();
    }

    private function cashAdvancePaymentTotalsByDate(): array
    {
        return EmployeeAdvancePayment::where('payment_type', 'abono_efectivo')
            ->whereBetween('payment_date', [$this->from, $this->to])
            ->selectRaw('DATE(payment_date) as fecha, SUM(amount) as total')
            ->groupBy('fecha')
            ->pluck('total', 'fecha')
            ->map(fn ($value) => (float) $value)
            ->toArray();
    }
}
