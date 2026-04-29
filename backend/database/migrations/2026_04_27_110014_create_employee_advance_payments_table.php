<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_advance_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('advance_id')->constrained('employee_advances')->restrictOnDelete();
            $table->foreignId('payroll_payment_id')->nullable()->constrained()->nullOnDelete(); // si fue descontado de nómina
            $table->foreignId('user_id')->constrained()->restrictOnDelete(); // quien registró el pago
            $table->decimal('amount', 12, 2);
            $table->enum('payment_type', ['descuento_nomina', 'abono_efectivo', 'ajuste_manual']);
            $table->date('payment_date');
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_advance_payments');
    }
};
