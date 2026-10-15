<?php

namespace Database\Seeders;

use App\Models\VehicleType;
use App\Models\WashService;
use App\Models\WashServiceType;
use Illuminate\Database\Seeder;

class WashServiceSeeder extends Seeder
{
    public function run(): void
    {
        $services = [
            'Carro' => [
                ['name' => 'Lavado general',   'base_price' => 100.00, 'is_custom' => false],
                ['name' => 'Lavado con motor', 'base_price' => 180.00, 'is_custom' => false],
                ['name' => 'Otro',             'base_price' => null,   'is_custom' => true],
            ],
            'Moto' => [
                ['name' => 'Lavado general',   'base_price' => 70.00,  'is_custom' => false],
                ['name' => 'Otro',             'base_price' => null,   'is_custom' => true],
            ],
            'Camión' => [
                ['name' => 'Lavado general',   'base_price' => 250.00, 'is_custom' => false],
                ['name' => 'Lavado con motor', 'base_price' => 350.00, 'is_custom' => false],
                ['name' => 'Otro',             'base_price' => null,   'is_custom' => true],
            ],
        ];

        foreach ($services as $vehicleTypeName => $list) {
            $vehicleType = VehicleType::where('name', $vehicleTypeName)->first();

            foreach ($list as $service) {
                // updateOrCreate para que al re-ejecutar el seeder actualice los precios
                $serviceType = WashServiceType::findOrCreateByName($service['name'], $service['is_custom']);

                WashService::updateOrCreate(
                    [
                        'wash_service_type_id' => $serviceType->id,
                        'vehicle_type_id'      => $vehicleType->id,
                    ],
                    [
                        'name'       => $serviceType->name,
                        'base_price' => $service['base_price'],
                        'is_custom'  => $service['is_custom'],
                        'is_active'  => true,
                    ]
                );
            }
        }
    }
}
