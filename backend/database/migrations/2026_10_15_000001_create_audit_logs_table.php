<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete(); // null = acción del sistema
            $table->string('event', 30);                  // created, updated, deleted, login
            $table->string('auditable_type')->nullable(); // clase del modelo afectado
            $table->unsignedBigInteger('auditable_id')->nullable();
            $table->json('old_values')->nullable();       // solo los campos que cambiaron
            $table->json('new_values')->nullable();
            $table->string('source', 10);                 // app, web, sistema
            $table->string('ip_address', 45)->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['auditable_type', 'auditable_id']);
            $table->index(['user_id', 'created_at']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
