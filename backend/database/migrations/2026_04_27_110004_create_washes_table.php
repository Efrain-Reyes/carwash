<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('washes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->foreignId('vehicle_type_id')->constrained()->restrictOnDelete();
            $table->foreignId('wash_service_id')->constrained()->restrictOnDelete();
            $table->string('custom_description')->nullable(); // solo cuando wash_service.is_custom = true
            $table->decimal('price', 12, 2);
            $table->enum('status', ['completado', 'anulado'])->default('completado');
            $table->text('notes')->nullable();
            $table->timestamp('registered_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('washes');
    }
};
