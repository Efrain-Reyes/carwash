<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // employee_advance_payments no tiene columna 'status' (usa 'payment_type'),
    // así que su índice compuesto es distinto al de las demás tablas.
    private array $tablesWithStatus = ['expenses', 'payroll_payments', 'employee_advances'];

    public function up(): void
    {
        foreach ($this->tablesWithStatus as $table) {
            Schema::table($table, function (Blueprint $blueprint) use ($table) {
                $blueprint->foreignId('cash_session_id')->nullable()->after('id')
                    ->constrained('cash_sessions')->nullOnDelete();
                $blueprint->index(['cash_session_id', 'status'], "{$table}_cash_session_status_idx");
            });
        }

        Schema::table('employee_advance_payments', function (Blueprint $blueprint) {
            $blueprint->foreignId('cash_session_id')->nullable()->after('id')
                ->constrained('cash_sessions')->nullOnDelete();
            $blueprint->index(['cash_session_id', 'payment_type'], 'employee_advance_payments_cash_session_type_idx');
        });
    }

    public function down(): void
    {
        foreach ($this->tablesWithStatus as $table) {
            Schema::table($table, function (Blueprint $blueprint) use ($table) {
                $blueprint->dropForeign(['cash_session_id']);
                $blueprint->dropIndex("{$table}_cash_session_status_idx");
                $blueprint->dropColumn('cash_session_id');
            });
        }

        Schema::table('employee_advance_payments', function (Blueprint $blueprint) {
            $blueprint->dropForeign(['cash_session_id']);
            $blueprint->dropIndex('employee_advance_payments_cash_session_type_idx');
            $blueprint->dropColumn('cash_session_id');
        });
    }
};
