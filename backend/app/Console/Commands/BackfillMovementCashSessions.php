<?php

namespace App\Console\Commands;

use App\Models\CashSession;
use App\Models\EmployeeAdvance;
use App\Models\EmployeeAdvancePayment;
use App\Models\Expense;
use App\Models\PayrollPayment;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class BackfillMovementCashSessions extends Command
{
    protected $signature = 'movements:backfill-cash-sessions
        {--apply : Ejecuta el UPDATE real. Sin esta opción solo se muestra un resumen (dry-run).}
        {--exclude-orphans : Junto con --apply, marca excluded_from_cash_session=true en los registros que sigan huérfanos después de asignar, para que NUNCA se cuenten en ningún cierre futuro (útil para historial de antes de usar caja).}';

    protected $description = 'Asigna cash_session_id a gastos, pagos de nómina, adelantos y abonos históricos (creados antes del fix), según la sesión de caja que estaba abierta en su fecha, replicando el criterio con el que ya se calcularon los cierres.';

    /** @var array<int, array{label: string, model: class-string, dateColumn: string, extra: \Closure}> */
    private array $entities;

    public function __construct()
    {
        parent::__construct();

        $this->entities = [
            [
                'label' => 'Gastos',
                'model' => Expense::class,
                'dateColumn' => 'expense_date',
                'extra' => fn (Builder $q) => $q->where('status', 'activo'),
            ],
            [
                'label' => 'Pagos de nómina',
                'model' => PayrollPayment::class,
                'dateColumn' => 'payment_date',
                'extra' => fn (Builder $q) => $q->where('status', 'pagado'),
            ],
            [
                'label' => 'Adelantos',
                'model' => EmployeeAdvance::class,
                'dateColumn' => 'advance_date',
                'extra' => fn (Builder $q) => $q->whereNotIn('status', ['anulado']),
            ],
            [
                'label' => 'Abonos de adelantos',
                'model' => EmployeeAdvancePayment::class,
                'dateColumn' => 'payment_date',
                'extra' => fn (Builder $q) => $q->where('payment_type', 'abono_efectivo'),
            ],
        ];
    }

    public function handle(): int
    {
        $apply = (bool) $this->option('apply');
        $excludeOrphans = (bool) $this->option('exclude-orphans');

        if ($excludeOrphans && ! $apply) {
            $this->error('--exclude-orphans solo tiene efecto junto con --apply.');

            return self::FAILURE;
        }

        $this->info($apply ? 'Modo APPLY: se aplicarán los cambios.' : 'Modo DRY-RUN: no se modifica nada, solo se muestra el resumen.');

        $sessions = CashSession::orderBy('opened_at')->orderBy('id')->get();

        if ($sessions->isEmpty()) {
            $this->warn('No hay sesiones de caja registradas.');

            return self::SUCCESS;
        }

        foreach ($this->entities as $entity) {
            $this->newLine();
            $this->line("=== {$entity['label']} ===");

            $totalAsignados = 0;
            /** @var class-string<\Illuminate\Database\Eloquent\Model> $modelClass */
            $modelClass = $entity['model'];

            foreach ($sessions as $session) {
                $to = $session->closed_at ?? now();

                $query = $modelClass::whereNull('cash_session_id')
                    ->where('excluded_from_cash_session', false)
                    ->whereBetween($entity['dateColumn'], [$session->opened_at, $to]);
                ($entity['extra'])($query);

                $count = (clone $query)->count();

                if ($count === 0) {
                    continue;
                }

                $this->line(sprintf(
                    'Sesión #%d (abierta %s%s): %d registros',
                    $session->id,
                    $session->opened_at->toDateTimeString(),
                    $session->closed_at ? ' → cerrada ' . $session->closed_at->toDateTimeString() : ' → sigue abierta',
                    $count
                ));

                if ($apply) {
                    DB::transaction(function () use ($query, $session) {
                        $query->update(['cash_session_id' => $session->id]);
                    });
                }

                $totalAsignados += $count;
            }

            $accion = $apply ? 'asignados' : 'que se asignarían (dry-run)';
            $this->info("Total {$accion}: {$totalAsignados}");

            $huerfanosQuery = $modelClass::whereNull('cash_session_id')->where('excluded_from_cash_session', false);
            ($entity['extra'])($huerfanosQuery);
            $huerfanosIds = (clone $huerfanosQuery)->pluck('id');

            if ($huerfanosIds->isEmpty()) {
                $this->info('No quedan huérfanos.');

                continue;
            }

            if ($excludeOrphans) {
                $modelClass::whereIn('id', $huerfanosIds)->update(['excluded_from_cash_session' => true]);
                $this->warn("Se marcaron {$huerfanosIds->count()} huérfanos como excluded_from_cash_session=true. NUNCA se contarán en ningún cierre futuro.");
            } else {
                $this->warn("Quedan {$huerfanosIds->count()} huérfanos — sin --exclude-orphans, serán reclamados automáticamente por el próximo cierre de caja.");
            }
        }

        return self::SUCCESS;
    }
}
