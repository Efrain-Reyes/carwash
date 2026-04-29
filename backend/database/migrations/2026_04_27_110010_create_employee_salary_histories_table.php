<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_salary_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained()->cascadeOnDelete();
            $table->decimal('salary', 12, 2);
            $table->enum('payment_frequency', ['diario', 'semanal', 'quincenal', 'mensual', 'otro']);
            $table->unsignedTinyInteger('work_days_per_period'); // días laborables en el periodo
            $table->decimal('daily_rate', 12, 2);               // calculado: salary / work_days_per_period
            $table->date('effective_from');
            $table->date('effective_to')->nullable(); // null = sueldo vigente actualmente
            $table->boolean('is_active')->default(true);
            $table->string('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_salary_histories');
    }
};
