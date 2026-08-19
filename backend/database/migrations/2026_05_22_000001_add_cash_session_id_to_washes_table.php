<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('washes', function (Blueprint $table) {
            $table->foreignId('cash_session_id')->nullable()->after('user_id')
                ->constrained('cash_sessions')->nullOnDelete();
            $table->index(['cash_session_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::table('washes', function (Blueprint $table) {
            $table->dropForeign(['cash_session_id']);
            $table->dropIndex(['cash_session_id', 'status']);
            $table->dropColumn('cash_session_id');
        });
    }
};
