<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RolesAndPermissionsSeeder::class, // primero: roles y permisos deben existir antes que usuarios
            AdminUserSeeder::class,           // segundo: el admin necesita los roles ya creados
            VehicleTypeSeeder::class,         // tercero: tipos de vehículo antes que servicios
            WashServiceSeeder::class,         // cuarto: servicios dependen de tipos de vehículo
        ]);
    }
}
