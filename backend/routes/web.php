<?php

use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\UserController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/admin');

// Panel web administrativo
Route::prefix('admin')->name('admin.')->group(function () {

    Route::get('login', [AuthController::class, 'showLogin'])->name('login');
    // Límite general por IP; el límite por correo está en AuthController::login().
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:20,1')->name('login.attempt');

    Route::middleware(['auth', 'admin'])->group(function () {
        Route::post('logout', [AuthController::class, 'logout'])->name('logout');

        Route::get('/', DashboardController::class)->name('dashboard');

        Route::get('usuarios', [UserController::class, 'index'])->name('users.index');
        Route::get('usuarios/nuevo', [UserController::class, 'create'])->name('users.create');
        Route::post('usuarios', [UserController::class, 'store'])->name('users.store');
        Route::get('usuarios/{user}/editar', [UserController::class, 'edit'])->name('users.edit');
        Route::put('usuarios/{user}', [UserController::class, 'update'])->name('users.update');
        Route::patch('usuarios/{user}/estado', [UserController::class, 'toggle'])->name('users.toggle');

        Route::get('bitacora', [AuditLogController::class, 'index'])->name('audit.index');
    });
});
