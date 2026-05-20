<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cash_session_adjustments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cash_session_id')->constrained('cash_sessions')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->decimal('old_counted_closing_amount', 12, 2)->nullable();
            $table->decimal('new_counted_closing_amount', 12, 2);
            $table->decimal('old_difference', 12, 2)->nullable();
            $table->decimal('new_difference', 12, 2);
            $table->text('old_notes')->nullable();
            $table->text('new_notes')->nullable();
            $table->text('reason');
            $table->timestamps();

            $table->index(['cash_session_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cash_session_adjustments');
    }
};
