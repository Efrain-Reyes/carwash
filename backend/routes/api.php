<?php

use App\Http\Controllers\Api\AdvanceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CashSessionController;
use App\Http\Controllers\Api\CatalogItemController;
use App\Http\Controllers\Api\EmployeeController;
use App\Http\Controllers\Api\ExpenseController;
use App\Http\Controllers\Api\PayrollController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\SupplierController;
use App\Http\Controllers\Api\VehicleTypeController;
use App\Http\Controllers\Api\WashController;
use App\Http\Controllers\Api\WashServiceController;
use Illuminate\Support\Facades\Route;

// Rutas públicas
Route::prefix('auth')->group(function () {
    Route::post('login', [AuthController::class, 'login']);
});

// Rutas protegidas
Route::middleware('auth:sanctum')->group(function () {

    Route::prefix('auth')->group(function () {
        Route::get('me', [AuthController::class, 'me']);
        Route::post('logout', [AuthController::class, 'logout']);
    });

    // Lavados
    Route::get('washes', [WashController::class, 'index'])->middleware('can:washes.view_own');
    Route::post('washes', [WashController::class, 'store'])->middleware('can:washes.create');
    Route::get('washes/{wash}', [WashController::class, 'show'])->middleware('can:washes.view_own');
    Route::patch('washes/{wash}/cancel', [WashController::class, 'cancel'])->middleware('can:wash.cancel');

    // Catálogo — tipos de vehículo
    Route::get('vehicle-types', [VehicleTypeController::class, 'index'])->middleware('can:vehicle_types.view');
    Route::post('vehicle-types', [VehicleTypeController::class, 'store'])->middleware('can:catalog.manage');
    Route::patch('vehicle-types/{vehicleType}/toggle', [VehicleTypeController::class, 'toggle'])->middleware('can:catalog.manage');

    // Catálogo — servicios de lavado
    Route::get('wash-services', [WashServiceController::class, 'index'])->middleware('can:wash_services.view');
    Route::post('wash-services', [WashServiceController::class, 'store'])->middleware('can:catalog.manage');
    Route::patch('wash-services/{washService}', [WashServiceController::class, 'update'])->middleware('can:catalog.manage');
    Route::patch('wash-services/{washService}/toggle', [WashServiceController::class, 'toggle'])->middleware('can:catalog.manage');

    // Catálogo — productos, insumos y servicios de gastos
    Route::get('catalog-items', [CatalogItemController::class, 'index'])->middleware('can:catalog.view');
    Route::post('catalog-items', [CatalogItemController::class, 'store'])->middleware('can:catalog.manage');
    Route::put('catalog-items/{catalogItem}', [CatalogItemController::class, 'update'])->middleware('can:catalog.manage');
    Route::patch('catalog-items/{catalogItem}/toggle', [CatalogItemController::class, 'toggle'])->middleware('can:catalog.manage');

    // Proveedores
    Route::get('suppliers', [SupplierController::class, 'index'])->middleware('can:supplier.view');
    Route::post('suppliers', [SupplierController::class, 'store'])->middleware('can:supplier.manage');
    Route::put('suppliers/{supplier}', [SupplierController::class, 'update'])->middleware('can:supplier.manage');
    Route::patch('suppliers/{supplier}/toggle', [SupplierController::class, 'toggle'])->middleware('can:supplier.manage');

    // Trabajadores
    Route::get('employees', [EmployeeController::class, 'index'])->middleware('can:employee.view');
    Route::post('employees', [EmployeeController::class, 'store'])->middleware('can:employee.manage');
    Route::get('employees/{employee}', [EmployeeController::class, 'show'])->middleware('can:employee.view');
    Route::put('employees/{employee}', [EmployeeController::class, 'update'])->middleware('can:employee.manage');
    Route::patch('employees/{employee}/toggle', [EmployeeController::class, 'toggle'])->middleware('can:employee.manage');
    Route::patch('employees/{employee}/deactivate', [EmployeeController::class, 'deactivate'])->middleware('can:employee.manage');
    Route::patch('employees/{employee}/activate', [EmployeeController::class, 'activate'])->middleware('can:employee.manage');
    Route::get('employees/{employee}/payroll-payments', [EmployeeController::class, 'payrollPayments'])->middleware('can:payroll.view');
    Route::get('employees/{employee}/salary-history', [EmployeeController::class, 'salaryHistory'])->middleware('can:employee.view');
    Route::post('employees/{employee}/salary', [EmployeeController::class, 'storeSalary'])->middleware('can:employee.manage');

    // Adelantos
    Route::get('advances', [AdvanceController::class, 'all'])->middleware('can:advance.view');
    Route::get('employees/{employee}/advances', [AdvanceController::class, 'index'])->middleware('can:advance.view');
    Route::post('employees/{employee}/advances', [AdvanceController::class, 'store'])->middleware('can:advance.manage');
    Route::get('advances/{advance}', [AdvanceController::class, 'show'])->middleware('can:advance.view');
    Route::put('advances/{advance}', [AdvanceController::class, 'update'])->middleware('can:advance.manage');
    Route::post('advances/{advance}/payments', [AdvanceController::class, 'storePayment'])->middleware('can:advance.manage');
    Route::patch('advances/{advance}/cancel', [AdvanceController::class, 'cancel'])->middleware('can:advance.manage');

    // Nómina — preview para formulario
    Route::get('employees/{employee}/payroll-preview', [PayrollController::class, 'payrollPreview'])->middleware('can:payroll.view');

    // Nómina — periodos
    Route::get('payroll-periods', [PayrollController::class, 'indexPeriods'])->middleware('can:payroll.view');
    Route::post('payroll-periods', [PayrollController::class, 'storePeriod'])->middleware('can:payroll.manage');
    Route::get('payroll-periods/{period}', [PayrollController::class, 'showPeriod'])->middleware('can:payroll.view');
    Route::patch('payroll-periods/{period}/close', [PayrollController::class, 'closePeriod'])->middleware('can:payroll.manage');
    Route::patch('payroll-periods/{period}/cancel', [PayrollController::class, 'cancelPeriod'])->middleware('can:payroll.manage');

    // Nómina — pagos individuales
    Route::post('payroll-periods/{period}/payments', [PayrollController::class, 'storePayment'])->middleware('can:payroll.manage');
    Route::get('payroll-payments/{payment}', [PayrollController::class, 'showPayment'])->middleware('can:payroll.view');
    Route::patch('payroll-payments/{payment}/confirm', [PayrollController::class, 'confirmPayment'])->middleware('can:payroll.manage');
    Route::patch('payroll-payments/{payment}/cancel', [PayrollController::class, 'cancelPayment'])->middleware('can:payroll.manage');

    // Reportes
    Route::get('reports/accounting', [ReportController::class, 'accounting'])->middleware('can:report.view');
    Route::get('reports/accounting/timeline', [ReportController::class, 'accountingTimeline'])->middleware('can:report.view');

    // Caja
    Route::get('cash-sessions/current', [CashSessionController::class, 'current'])->middleware('can:cash.view');
    Route::get('cash-sessions', [CashSessionController::class, 'index'])->middleware('can:cash.manage');
    Route::post('cash-sessions', [CashSessionController::class, 'store'])->middleware('can:cash.manage');
    Route::get('cash-sessions/{cashSession}', [CashSessionController::class, 'show'])->middleware('can:cash.manage');
    Route::patch('cash-sessions/{cashSession}/close', [CashSessionController::class, 'close'])->middleware('can:cash.manage');
    Route::patch('cash-sessions/{cashSession}/closing-adjustment', [CashSessionController::class, 'adjustClosing'])->middleware('can:cash.manage');

    // Gastos
    Route::get('expenses', [ExpenseController::class, 'index'])->middleware('can:expense.view');
    Route::post('expenses', [ExpenseController::class, 'store'])->middleware('can:expense.create');
    Route::get('expenses/{expense}', [ExpenseController::class, 'show'])->middleware('can:expense.view');
    Route::patch('expenses/{expense}/cancel', [ExpenseController::class, 'cancel'])->middleware('can:expense.cancel');

});
