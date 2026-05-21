<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RolesAndPermissionsSeeder extends Seeder
{
    public function run(): void
    {
        // Limpiar caché de permisos para evitar conflictos
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        $permissions = [
            // Lavados
            'wash.view',
            'wash.create',
            'wash.cancel',
            'washes.create',
            'washes.view_own',
            'vehicle_types.view',
            'wash_services.view',

            // Gastos
            'expense.view',
            'expense.create',
            'expense.cancel',

            // Catálogo de productos/insumos/servicios
            'catalog.view',
            'catalog.manage',

            // Proveedores
            'supplier.view',
            'supplier.manage',

            // Trabajadores
            'employee.view',
            'employee.manage',

            // Nómina
            'payroll.view',
            'payroll.manage',

            // Adelantos
            'advance.view',
            'advance.manage',

            // Reportes contables
            'report.view',

            // Caja
            'cash.view',
            'cash.manage',

            // Usuarios del sistema
            'user.manage',
        ];

        foreach ($permissions as $permission) {
            Permission::firstOrCreate(['name' => $permission]);
        }

        $admin = Role::firstOrCreate(['name' => 'administrador']);
        $admin->syncPermissions($permissions);

        $operator = Role::firstOrCreate(['name' => 'operador']);
        $operator->syncPermissions([
            'washes.create',
            'washes.view_own',
            'vehicle_types.view',
            'wash_services.view',
        ]);
    }
}
