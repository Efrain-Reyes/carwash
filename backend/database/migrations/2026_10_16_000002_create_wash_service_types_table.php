<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Matriz de precios.
 *
 * Antes cada servicio se repetía por vehículo ("Lavado general" de Carro, de Moto...).
 * Ahora wash_service_types define el servicio una sola vez y cada fila de wash_services
 * queda como "este servicio, para este vehículo, a este precio". Se conservan los ids
 * de wash_services para que los lavados ya registrados y la app no cambien.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wash_service_types', function (Blueprint $table) {
            $table->id();
            $table->string('name', 100)->unique();
            $table->boolean('is_custom')->default(false); // true = "Otro": precio y descripción se escriben al registrar
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::table('wash_services', function (Blueprint $table) {
            $table->foreignId('wash_service_type_id')->nullable()->after('id')
                ->constrained('wash_service_types')->restrictOnDelete();
        });

        // Agrupa los servicios existentes por nombre (sin importar mayúsculas ni espacios).
        $groups = DB::table('wash_services')->orderBy('id')->get()
            ->groupBy(fn ($service) => mb_strtolower(trim($service->name)));

        $sortOrder = 0;
        foreach ($groups as $services) {
            $first = $services->first();

            $typeId = DB::table('wash_service_types')->insertGetId([
                'name'       => trim($first->name),
                'is_custom'  => $services->contains(fn ($s) => (bool) $s->is_custom),
                'is_active'  => $services->contains(fn ($s) => (bool) $s->is_active),
                'sort_order' => ++$sortOrder,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('wash_services')
                ->whereIn('id', $services->pluck('id'))
                ->update(['wash_service_type_id' => $typeId, 'name' => trim($first->name)]);
        }

        // Un servicio solo puede tener un precio por tipo de vehículo.
        Schema::table('wash_services', function (Blueprint $table) {
            $table->unique(['wash_service_type_id', 'vehicle_type_id']);
        });
    }

    public function down(): void
    {
        Schema::table('wash_services', function (Blueprint $table) {
            $table->dropUnique(['wash_service_type_id', 'vehicle_type_id']);
            $table->dropConstrainedForeignId('wash_service_type_id');
        });

        Schema::dropIfExists('wash_service_types');
    }
};
