<?php

use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

return new class extends Migration
{
    public function up(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $operatorPermissions = [
            'washes.create',
            'washes.view_own',
            'vehicle_types.view',
            'wash_services.view',
        ];

        foreach ($operatorPermissions as $permission) {
            Permission::firstOrCreate(['name' => $permission]);
        }

        $admin = Role::firstOrCreate(['name' => 'administrador']);
        $admin->givePermissionTo($operatorPermissions);

        $operator = Role::firstOrCreate(['name' => 'operador']);
        $operator->syncPermissions($operatorPermissions);

        $forbiddenOperatorPermissions = [
            'wash.view',
            'wash.create',
            'wash.cancel',
            'advance.view',
            'advance.manage',
            'cash.view',
            'cash.manage',
            'report.view',
            'expense.view',
            'expense.create',
            'expense.cancel',
            'payroll.view',
            'payroll.manage',
            'employee.view',
            'employee.manage',
            'catalog.view',
            'catalog.manage',
            'supplier.view',
            'supplier.manage',
            'user.manage',
        ];

        User::role('operador')->each(function (User $user) use ($operatorPermissions, $forbiddenOperatorPermissions) {
            $user->givePermissionTo($operatorPermissions);
            $user->revokePermissionTo($forbiddenOperatorPermissions);
        });

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    public function down(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $legacyOperatorPermissions = [
            'wash.view',
            'wash.create',
            'advance.view',
            'cash.view',
        ];

        $operator = Role::firstOrCreate(['name' => 'operador']);
        $operator->syncPermissions($legacyOperatorPermissions);

        User::role('operador')->each(function (User $user) use ($legacyOperatorPermissions) {
            $user->givePermissionTo($legacyOperatorPermissions);
        });

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }
};
