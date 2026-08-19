<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private array $tables = ['washes', 'expenses', 'payroll_payments', 'employee_advances', 'employee_advance_payments'];

    public function up(): void
    {
        foreach ($this->tables as $table) {
            Schema::table($table, function (Blueprint $blueprint) {
                // Marca movimientos históricos (de antes de que existiera el módulo de
                // caja, o clasificados manualmente) que NUNCA deben contarse en ningún
                // cierre de caja, ni pasado ni futuro — a diferencia de cash_session_id
                // nulo, que significa "pendiente de reclamar" y sí se cuenta.
                $blueprint->boolean('excluded_from_cash_session')->default(false)->after('cash_session_id');
            });
        }
    }

    public function down(): void
    {
        foreach ($this->tables as $table) {
            Schema::table($table, function (Blueprint $blueprint) {
                $blueprint->dropColumn('excluded_from_cash_session');
            });
        }
    }
};
