<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\PermissionRegistrar;

class TestOperatorSeeder extends Seeder
{
    public function run(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        /*
         * Usa el mismo nombre de rol que maneja tu sistema.
         * Si tu proyecto usa "operator" en vez de "operador", cambia esta línea.
         */
        $roleName = 'operador';

        $guardName = config('auth.defaults.guard', 'web');

        $operatorPermissions = [
            'washes.create',
            'washes.view_own',
            'vehicle_types.view',
            'wash_services.view',
        ];

        foreach ($operatorPermissions as $permissionName) {
            Permission::firstOrCreate([
                'name' => $permissionName,
                'guard_name' => $guardName,
            ]);
        }

        $operatorRole = Role::firstOrCreate([
            'name' => $roleName,
            'guard_name' => $guardName,
        ]);

        // Dejamos al operador solo con permisos mínimos.
        $operatorRole->syncPermissions($operatorPermissions);

        $operator = User::updateOrCreate(
            ['email' => 'juan@carwash.test'],
            [
                'name' => 'Juan operador',
                'password' => Hash::make('123'),
                'email_verified_at' => now(),
            ]
        );

        $operator->syncRoles([$operatorRole]);

        // Opcional: elimina tokens viejos para que inicie sesión limpio.
        if (method_exists($operator, 'tokens')) {
            $operator->tokens()->delete();
        }

        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $this->command->info('Operador de prueba creado correctamente.');
        $this->command->info('Email: juan@carwash.test');
        $this->command->info('Password: 123');
    }
}
