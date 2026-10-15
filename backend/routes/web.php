<?php

use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\ExpenseCategoryController;
use App\Http\Controllers\Admin\ExpenseItemController;
use App\Http\Controllers\Admin\SupplierController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Admin\VehicleTypeController;
use App\Http\Controllers\Admin\WashServiceController;
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

        // Catálogos: nada se borra, se desactiva (los lavados y gastos viejos los siguen usando).
        Route::prefix('catalogo')->name('catalog.')->group(function () {
            Route::get('vehiculos', [VehicleTypeController::class, 'index'])->name('vehicles.index');
            Route::get('vehiculos/nuevo', [VehicleTypeController::class, 'create'])->name('vehicles.create');
            Route::post('vehiculos', [VehicleTypeController::class, 'store'])->name('vehicles.store');
            Route::get('vehiculos/{vehicleType}/editar', [VehicleTypeController::class, 'edit'])->name('vehicles.edit');
            Route::put('vehiculos/{vehicleType}', [VehicleTypeController::class, 'update'])->name('vehicles.update');
            Route::patch('vehiculos/{vehicleType}/estado', [VehicleTypeController::class, 'toggle'])->name('vehicles.toggle');

            Route::get('servicios', [WashServiceController::class, 'index'])->name('services.index');
            Route::put('servicios/precios', [WashServiceController::class, 'updatePrices'])->name('services.prices');
            Route::get('servicios/nuevo', [WashServiceController::class, 'create'])->name('services.create');
            Route::post('servicios', [WashServiceController::class, 'store'])->name('services.store');
            Route::get('servicios/{serviceType}/editar', [WashServiceController::class, 'edit'])->name('services.edit');
            Route::put('servicios/{serviceType}', [WashServiceController::class, 'update'])->name('services.update');
            Route::patch('servicios/{serviceType}/estado', [WashServiceController::class, 'toggle'])->name('services.toggle');

            Route::get('proveedores', [SupplierController::class, 'index'])->name('suppliers.index');
            Route::get('proveedores/nuevo', [SupplierController::class, 'create'])->name('suppliers.create');
            Route::post('proveedores', [SupplierController::class, 'store'])->name('suppliers.store');
            Route::get('proveedores/{supplier}/editar', [SupplierController::class, 'edit'])->name('suppliers.edit');
            Route::put('proveedores/{supplier}', [SupplierController::class, 'update'])->name('suppliers.update');
            Route::patch('proveedores/{supplier}/estado', [SupplierController::class, 'toggle'])->name('suppliers.toggle');

            Route::get('gastos/articulos', [ExpenseItemController::class, 'index'])->name('expense-items.index');
            Route::get('gastos/articulos/nuevo', [ExpenseItemController::class, 'create'])->name('expense-items.create');
            Route::post('gastos/articulos', [ExpenseItemController::class, 'store'])->name('expense-items.store');
            Route::get('gastos/articulos/{item}/editar', [ExpenseItemController::class, 'edit'])->name('expense-items.edit');
            Route::put('gastos/articulos/{item}', [ExpenseItemController::class, 'update'])->name('expense-items.update');
            Route::patch('gastos/articulos/{item}/estado', [ExpenseItemController::class, 'toggle'])->name('expense-items.toggle');

            Route::get('gastos/categorias', [ExpenseCategoryController::class, 'index'])->name('expense-categories.index');
            Route::get('gastos/categorias/nueva', [ExpenseCategoryController::class, 'create'])->name('expense-categories.create');
            Route::post('gastos/categorias', [ExpenseCategoryController::class, 'store'])->name('expense-categories.store');
            Route::get('gastos/categorias/{category}/editar', [ExpenseCategoryController::class, 'edit'])->name('expense-categories.edit');
            Route::put('gastos/categorias/{category}', [ExpenseCategoryController::class, 'update'])->name('expense-categories.update');
            Route::patch('gastos/categorias/{category}/estado', [ExpenseCategoryController::class, 'toggle'])->name('expense-categories.toggle');
        });
    });
});
