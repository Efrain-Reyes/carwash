<?php

namespace Database\Seeders;

use App\Models\VehicleType;
use Illuminate\Database\Seeder;

class VehicleTypeSeeder extends Seeder
{
    public function run(): void
    {
        $types = [
            ['name' => 'Carro', 'icon' => 'car'],
            ['name' => 'Moto', 'icon' => 'motorcycle'],
            ['name' => 'Camión', 'icon' => 'truck'],
        ];

        foreach ($types as $index => $type) {
            VehicleType::firstOrCreate(['name' => $type['name']], [
                'icon'       => $type['icon'],
                'sort_order' => $index + 1,
            ]);
        }
    }
}
