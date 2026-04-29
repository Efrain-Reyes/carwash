<?php

namespace Database\Seeders;

use App\Models\VehicleType;
use Illuminate\Database\Seeder;

class VehicleTypeSeeder extends Seeder
{
    public function run(): void
    {
        $types = ['Carro', 'Moto', 'Camión'];

        foreach ($types as $name) {
            VehicleType::firstOrCreate(['name' => $name]);
        }
    }
}
