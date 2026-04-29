<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_advances', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained()->restrictOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete(); // admin que registró
            $table->decimal('amount', 12, 2);            // monto original entregado
            $table->decimal('balance', 12, 2);           // saldo pendiente (inicia igual a amount)
            $table->date('advance_date');
            $table->enum('status', ['pendiente', 'parcialmente_pagado', 'pagado', 'anulado'])->default('pendiente');
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_advances');
    }
};
