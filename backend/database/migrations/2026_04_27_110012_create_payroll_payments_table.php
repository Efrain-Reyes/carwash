<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payroll_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('payroll_period_id')->constrained()->restrictOnDelete();
            $table->foreignId('employee_id')->constrained()->restrictOnDelete();
            $table->foreignId('salary_history_id')->constrained('employee_salary_histories')->restrictOnDelete();
            $table->foreignId('processed_by')->constrained('users')->restrictOnDelete();

            // Snapshots del sueldo al momento del pago
            $table->decimal('base_salary', 12, 2);
            $table->decimal('daily_rate', 12, 2);
            $table->unsignedTinyInteger('work_days_per_period');

            // Cálculo del pago
            $table->decimal('days_worked', 5, 2);
            $table->decimal('gross_amount', 12, 2);          // days_worked * daily_rate
            $table->decimal('extra_payments', 12, 2)->default(0.00);     // bonos u otros ingresos
            $table->decimal('advance_discount', 12, 2)->default(0.00);   // descuento aplicado de adelantos
            $table->decimal('other_deductions', 12, 2)->default(0.00);   // otras deducciones
            $table->decimal('net_amount', 12, 2);            // gross + extra - advance_discount - other_deductions

            $table->date('payment_date');
            $table->enum('status', ['borrador', 'pagado', 'anulado'])->default('borrador');
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payroll_payments');
    }
};
