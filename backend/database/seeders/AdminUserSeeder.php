<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::firstOrCreate(
            ['email' => 'admin@carwash.com'],
            [
                'name'      => 'Administrador',
                'password'  => bcrypt('password'),
                'is_active' => true,
            ]
        );

        $admin->assignRole('administrador');
    }
}
