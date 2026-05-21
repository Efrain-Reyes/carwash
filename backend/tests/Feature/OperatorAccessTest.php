<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\VehicleType;
use App\Models\Wash;
use App\Models\WashService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class OperatorAccessTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Carbon::setTestNow(Carbon::parse('2026-05-21 10:00:00', config('app.timezone')));
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_operator_can_create_wash_associated_to_their_user(): void
    {
        [$vehicleType, $service] = $this->vehicleAndService();
        $operator = $this->operator();

        $this->actingAs($operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $vehicleType->id,
                'wash_service_id' => $service->id,
            ])
            ->assertCreated()
            ->assertJsonPath('user.id', $operator->id)
            ->assertJsonPath('price', '250.00');

        $this->assertDatabaseHas('washes', [
            'user_id' => $operator->id,
            'vehicle_type_id' => $vehicleType->id,
            'wash_service_id' => $service->id,
            'price' => 250,
            'status' => 'completado',
        ]);
    }

    public function test_operator_can_create_custom_wash_with_description_and_price(): void
    {
        $vehicleType = VehicleType::create(['name' => 'Carro', 'is_active' => true]);
        $service = WashService::create([
            'vehicle_type_id' => $vehicleType->id,
            'name' => 'Otro',
            'base_price' => null,
            'is_custom' => true,
            'is_active' => true,
        ]);

        $this->actingAs($this->operator(), 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $vehicleType->id,
                'wash_service_id' => $service->id,
                'custom_description' => 'Lavado especial',
                'price' => 375,
            ])
            ->assertCreated()
            ->assertJsonPath('custom_description', 'Lavado especial')
            ->assertJsonPath('price', '375.00');
    }

    public function test_operator_only_sees_their_own_washes(): void
    {
        [$vehicleType, $service] = $this->vehicleAndService();
        $operator = $this->operator();
        $otherOperator = $this->operator();

        $ownWash = Wash::create([
            'user_id' => $operator->id,
            'vehicle_type_id' => $vehicleType->id,
            'wash_service_id' => $service->id,
            'price' => 250,
            'status' => 'completado',
            'registered_at' => Carbon::parse('2026-05-21 09:00:00', config('app.timezone')),
        ]);
        Wash::create([
            'user_id' => $otherOperator->id,
            'vehicle_type_id' => $vehicleType->id,
            'wash_service_id' => $service->id,
            'price' => 250,
            'status' => 'completado',
            'registered_at' => Carbon::parse('2026-05-21 09:05:00', config('app.timezone')),
        ]);

        $response = $this->actingAs($operator, 'sanctum')
            ->getJson('/api/washes?date_from=2026-05-21&date_to=2026-05-21')
            ->assertOk();

        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $ownWash->id);

        $this->actingAs($operator, 'sanctum')
            ->getJson('/api/washes/'.$ownWash->id)
            ->assertOk();
    }

    public function test_operator_cannot_view_another_operator_wash(): void
    {
        [$vehicleType, $service] = $this->vehicleAndService();
        $operator = $this->operator();
        $otherOperator = $this->operator();

        $otherWash = Wash::create([
            'user_id' => $otherOperator->id,
            'vehicle_type_id' => $vehicleType->id,
            'wash_service_id' => $service->id,
            'price' => 250,
            'status' => 'completado',
            'registered_at' => now(),
        ]);

        $this->actingAs($operator, 'sanctum')
            ->getJson('/api/washes/'.$otherWash->id)
            ->assertForbidden();
    }

    public function test_operator_can_view_vehicle_types_and_wash_services(): void
    {
        [$vehicleType, $service] = $this->vehicleAndService();

        $this->actingAs($this->operator(), 'sanctum')
            ->getJson('/api/vehicle-types')
            ->assertOk()
            ->assertJsonPath('0.id', $vehicleType->id);

        $this->actingAs($this->operator(), 'sanctum')
            ->getJson('/api/wash-services?vehicle_type_id='.$vehicleType->id)
            ->assertOk()
            ->assertJsonPath('0.id', $service->id);
    }

    public function test_operator_cannot_access_administrative_endpoints(): void
    {
        $operator = $this->operator();

        $this->actingAs($operator, 'sanctum')->getJson('/api/reports/accounting?date_from=2026-05-21&date_to=2026-05-21')->assertForbidden();
        $this->actingAs($operator, 'sanctum')->getJson('/api/cash-sessions/current')->assertForbidden();
        $this->actingAs($operator, 'sanctum')->getJson('/api/cash-sessions')->assertForbidden();
        $this->actingAs($operator, 'sanctum')->getJson('/api/expenses')->assertForbidden();
        $this->actingAs($operator, 'sanctum')->getJson('/api/advances')->assertForbidden();
        $this->actingAs($operator, 'sanctum')->getJson('/api/employees')->assertForbidden();
        $this->actingAs($operator, 'sanctum')->getJson('/api/payroll-periods')->assertForbidden();
    }

    public function test_operator_cannot_modify_catalogs_or_prices(): void
    {
        [$vehicleType, $service] = $this->vehicleAndService();
        $operator = $this->operator();

        $this->actingAs($operator, 'sanctum')
            ->patchJson('/api/wash-services/'.$service->id, ['base_price' => 1])
            ->assertForbidden();

        $this->actingAs($operator, 'sanctum')
            ->patchJson('/api/wash-services/'.$service->id.'/toggle')
            ->assertForbidden();

        $this->actingAs($operator, 'sanctum')
            ->patchJson('/api/vehicle-types/'.$vehicleType->id.'/toggle')
            ->assertForbidden();
    }

    private function vehicleAndService(): array
    {
        $vehicleType = VehicleType::create(['name' => 'Carro', 'is_active' => true]);
        $service = WashService::create([
            'vehicle_type_id' => $vehicleType->id,
            'name' => 'Lavado básico',
            'base_price' => 250,
            'is_custom' => false,
            'is_active' => true,
        ]);

        return [$vehicleType, $service];
    }

    private function operator(): User
    {
        $user = User::factory()->create();
        $user->assignRole('operador');

        return $user;
    }
}
