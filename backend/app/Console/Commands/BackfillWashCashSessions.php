<?php

namespace App\Console\Commands;

use App\Models\CashSession;
use App\Models\Wash;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class BackfillWashCashSessions extends Command
{
    protected $signature = 'washes:backfill-cash-sessions {--apply : Ejecuta el UPDATE real. Sin esta opción solo se muestra un resumen (dry-run).}';

    protected $description = 'Asigna cash_session_id a lavados históricos (creados antes del fix) según la sesión de caja que estaba abierta en registered_at, replicando el criterio con el que ya se calcularon los cierres.';

    public function handle(): int
    {
        $apply = (bool) $this->option('apply');

        $this->info($apply ? 'Modo APPLY: se aplicarán los cambios.' : 'Modo DRY-RUN: no se modifica nada, solo se muestra el resumen.');

        $sessions = CashSession::orderBy('opened_at')->orderBy('id')->get();

        if ($sessions->isEmpty()) {
            $this->warn('No hay sesiones de caja registradas.');

            return self::SUCCESS;
        }

        $totalAsignados = 0;

        foreach ($sessions as $session) {
            $to = $session->closed_at ?? now();

            $query = Wash::whereNull('cash_session_id')
                ->where('status', 'completado')
                ->whereBetween('registered_at', [$session->opened_at, $to]);

            $count = (clone $query)->count();
            $sum = (clone $query)->sum('price');

            if ($count === 0) {
                continue;
            }

            $this->line(sprintf(
                'Sesión #%d (abierta %s%s): %d lavados por L %s',
                $session->id,
                $session->opened_at->toDateTimeString(),
                $session->closed_at ? ' → cerrada ' . $session->closed_at->toDateTimeString() : ' → sigue abierta',
                $count,
                number_format((float) $sum, 2)
            ));

            if ($apply) {
                DB::transaction(function () use ($query, $session) {
                    $query->update(['cash_session_id' => $session->id]);
                });
            }

            $totalAsignados += $count;
        }

        $this->newLine();
        $this->info("Total de lavados {$this->accionLabel($apply)}: {$totalAsignados}");

        $huerfanos = Wash::whereNull('cash_session_id')
            ->where('status', 'completado')
            ->orderBy('registered_at')
            ->get(['id', 'registered_at', 'price', 'user_id', 'notes']);

        if ($huerfanos->isEmpty()) {
            $this->info('No quedan lavados huérfanos (todos calzan dentro de alguna sesión).');

            return self::SUCCESS;
        }

        $this->newLine();
        $this->warn("Quedan {$huerfanos->count()} lavados huérfanos (no calzan en ninguna sesión por fecha). Serán reclamados automáticamente por el próximo cierre de caja que se ejecute:");

        $this->table(
            ['ID', 'registered_at', 'price', 'user_id', 'notes'],
            $huerfanos->map(fn (Wash $w) => [
                $w->id,
                $w->registered_at->toDateTimeString(),
                number_format((float) $w->price, 2),
                $w->user_id,
                $w->notes,
            ])
        );

        $this->info('Monto total de huérfanos: L ' . number_format((float) $huerfanos->sum('price'), 2));

        return self::SUCCESS;
    }

    private function accionLabel(bool $apply): string
    {
        return $apply ? 'asignados' : 'que se asignarían (dry-run)';
    }
}
