<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vehicle_types', function (Blueprint $table) {
            $table->string('icon', 30)->default('car')->after('name');    // clave de VehicleType::ICONS
            $table->unsignedSmallInteger('sort_order')->default(0)->after('icon');
        });

        // Antes el icono se adivinaba por el nombre en la app; se conserva ese mismo resultado.
        foreach (DB::table('vehicle_types')->orderBy('id')->get() as $index => $type) {
            $name = mb_strtolower($type->name);

            $icon = match (true) {
                str_contains($name, 'moto') => 'motorcycle',
                str_contains($name, 'camio') || str_contains($name, 'truck') => 'truck',
                default => 'car',
            };

            DB::table('vehicle_types')->where('id', $type->id)->update([
                'icon'       => $icon,
                'sort_order' => $index + 1,
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('vehicle_types', function (Blueprint $table) {
            $table->dropColumn(['icon', 'sort_order']);
        });
    }
};
