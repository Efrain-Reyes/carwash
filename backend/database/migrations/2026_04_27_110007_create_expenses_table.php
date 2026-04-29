<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('expenses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->foreignId('supplier_id')->constrained('expense_suppliers')->restrictOnDelete();
            $table->string('invoice_number')->nullable();      // número de factura real
            $table->boolean('is_internal_invoice')->default(false);
            $table->unsignedInteger('internal_correlative')->nullable(); // correlativo auto cuando no hay factura
            $table->decimal('subtotal', 12, 2)->default(0.00);
            $table->decimal('tax_amount', 12, 2)->default(0.00);
            $table->decimal('total', 12, 2)->default(0.00);
            $table->datetime('expense_date');
            $table->text('notes')->nullable();
            $table->enum('status', ['activo', 'anulado'])->default('activo');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expenses');
    }
};
