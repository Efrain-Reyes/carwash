<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('expense_catalog_items', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->enum('type', ['producto', 'insumo', 'servicio']);
            $table->decimal('base_price', 12, 2)->nullable();
            $table->decimal('tax_rate', 5, 2)->default(0.00); // porcentaje, ej: 15.00
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expense_catalog_items');
    }
};
