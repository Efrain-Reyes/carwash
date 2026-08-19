<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\VehicleType;
use App\Models\WashService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CatalogManagementTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_admin_can_create_a_new_vehicle_type(): void
    {
        $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/vehicle-types', ['name' => 'Camioneta 4 puertas'])
            ->assertCreated()
            ->assertJsonPath('name', 'Camioneta 4 puertas')
            ->assertJsonPath('is_active', true);

        $this->assertDatabaseHas('vehicle_types', ['name' => 'Camioneta 4 puertas', 'is_active' => true]);
    }

    public function test_operator_cannot_create_a_vehicle_type(): void
    {
        $this->actingAs($this->operator(), 'sanctum')
            ->postJson('/api/vehicle-types', ['name' => 'Camioneta'])
            ->assertForbidden();
    }

    public function test_admin_can_create_a_non_custom_service_with_price(): void
    {
        $vehicleType = VehicleType::create(['name' => 'Carro', 'is_active' => true]);

        $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/wash-services', [
                'vehicle_type_id' => $vehicleType->id,
                'name' => 'Lavado premium',
                'is_custom' => false,
                'base_price' => 350,
            ])
            ->assertCreated()
            ->assertJsonPath('name', 'Lavado premium')
            ->assertJsonPath('base_price', '350.00');

        $this->assertDatabaseHas('wash_services', [
            'vehicle_type_id' => $vehicleType->id,
            'name' => 'Lavado premium',
            'base_price' => 350,
            'is_custom' => false,
        ]);
    }

    public function test_creating_non_custom_service_without_price_is_rejected(): void
    {
        $vehicleType = VehicleType::create(['name' => 'Carro', 'is_active' => true]);

        $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/wash-services', [
                'vehicle_type_id' => $vehicleType->id,
                'name' => 'Servicio sin precio',
                'is_custom' => false,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['base_price']);
    }

    public function test_admin_can_create_a_custom_service_without_price(): void
    {
        $vehicleType = VehicleType::create(['name' => 'Carro', 'is_active' => true]);

        $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/wash-services', [
                'vehicle_type_id' => $vehicleType->id,
                'name' => 'Otro',
                'is_custom' => true,
            ])
            ->assertCreated()
            ->assertJsonPath('is_custom', true)
            ->assertJsonPath('base_price', null);
    }

    public function test_operator_cannot_create_a_wash_service(): void
    {
        $vehicleType = VehicleType::create(['name' => 'Carro', 'is_active' => true]);

        $this->actingAs($this->operator(), 'sanctum')
            ->postJson('/api/wash-services', [
                'vehicle_type_id' => $vehicleType->id,
                'name' => 'Lavado',
                'is_custom' => false,
                'base_price' => 100,
            ])
            ->assertForbidden();
    }

    public function test_admin_sees_inactive_items_only_with_include_inactive_flag(): void
    {
        $vehicleType = VehicleType::create(['name' => 'Moto', 'is_active' => false]);
        WashService::create([
            'vehicle_type_id' => $vehicleType->id,
            'name' => 'Lavado moto',
            'base_price' => 80,
            'is_custom' => false,
            'is_active' => false,
        ]);

        $this->actingAs($this->admin(), 'sanctum')
            ->getJson('/api/vehicle-types')
            ->assertOk()
            ->assertJsonCount(0);

        $this->actingAs($this->admin(), 'sanctum')
            ->getJson('/api/vehicle-types?include_inactive=1')
            ->assertOk()
            ->assertJsonCount(1);
    }

    private function admin(): User
    {
        $user = User::factory()->create();
        $user->assignRole('administrador');

        return $user;
    }

    private function operator(): User
    {
        $user = User::factory()->create();
        $user->assignRole('operador');

        return $user;
    }
}
