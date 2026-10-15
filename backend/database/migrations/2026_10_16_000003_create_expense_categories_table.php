<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Las categorías de gastos dejan de ser una lista fija (producto, insumo, servicio)
 * y pasan a ser un catálogo editable desde el panel.
 */
return new class extends Migration
{
    private const LEGACY = [
        'producto' => 'Producto',
        'insumo'   => 'Insumo',
        'servicio' => 'Servicio',
    ];

    public function up(): void
    {
        Schema::create('expense_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name', 100)->unique();
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });

        $categoryIds = [];
        foreach (array_values(self::LEGACY) as $index => $name) {
            $categoryIds[$name] = DB::table('expense_categories')->insertGetId([
                'name'       => $name,
                'sort_order' => $index + 1,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        Schema::table('expense_catalog_items', function (Blueprint $table) {
            $table->foreignId('expense_category_id')->nullable()->after('name')
                ->constrained('expense_categories')->restrictOnDelete();
        });

        foreach (self::LEGACY as $type => $name) {
            DB::table('expense_catalog_items')
                ->where('type', $type)
                ->update(['expense_category_id' => $categoryIds[$name]]);
        }

        Schema::table('expense_catalog_items', function (Blueprint $table) {
            $table->dropColumn('type');
        });
    }

    public function down(): void
    {
        Schema::table('expense_catalog_items', function (Blueprint $table) {
            $table->enum('type', array_keys(self::LEGACY))->default('producto')->after('name');
        });

        foreach (self::LEGACY as $type => $name) {
            $categoryId = DB::table('expense_categories')->where('name', $name)->value('id');

            DB::table('expense_catalog_items')
                ->where('expense_category_id', $categoryId)
                ->update(['type' => $type]);
        }

        Schema::table('expense_catalog_items', function (Blueprint $table) {
            $table->dropConstrainedForeignId('expense_category_id');
        });

        Schema::dropIfExists('expense_categories');
    }
};
