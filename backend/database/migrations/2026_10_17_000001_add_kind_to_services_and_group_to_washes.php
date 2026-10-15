<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lavados y extras.
 *
 * - kind: "lavado" (Express, Completo...) o "extra" (cristal perfecto, calibración...).
 *   Los extras se cobran igual pero no cuentan como lavados en los reportes.
 *   wash_services guarda una copia, igual que el nombre, para que la app y los
 *   reportes no tengan que consultar wash_service_types.
 * - group_uuid: los servicios que se registran juntos (un lavado + sus extras)
 *   comparten este identificador.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wash_service_types', function (Blueprint $table) {
            $table->string('kind', 10)->default('lavado')->after('name');
        });

        Schema::table('wash_services', function (Blueprint $table) {
            $table->string('kind', 10)->default('lavado')->after('name');
        });

        Schema::table('washes', function (Blueprint $table) {
            $table->uuid('group_uuid')->nullable()->after('id')->index();
        });
    }

    public function down(): void
    {
        Schema::table('washes', function (Blueprint $table) {
            $table->dropIndex(['group_uuid']);
            $table->dropColumn('group_uuid');
        });

        Schema::table('wash_services', function (Blueprint $table) {
            $table->dropColumn('kind');
        });

        Schema::table('wash_service_types', function (Blueprint $table) {
            $table->dropColumn('kind');
        });
    }
};
