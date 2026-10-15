<?php

namespace Tests\Feature;

use App\Models\CashSession;
use App\Models\User;
use App\Models\VehicleType;
use App\Models\Wash;
use App\Models\WashService;
use App\Models\WashServiceType;
use Database\Seeders\RolesAndPermissionsSeeder;
use Database\Seeders\VehicleTypeSeeder;
use Database\Seeders\WashServiceSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Lavados con extras: un lavado + extras en un solo registro, o solo extras. */
class WashExtrasTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $operator;

    private VehicleType $carro;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed([RolesAndPermissionsSeeder::class, VehicleTypeSeeder::class, WashServiceSeeder::class]);
        $this->withoutVite();

        $this->admin = User::factory()->create(['is_active' => true]);
        $this->admin->assignRole('administrador');
        $this->operator = User::factory()->create(['is_active' => true]);
        $this->operator->assignRole('operador');

        $this->carro = VehicleType::where('name', 'Carro')->first();

        // Dos extras con precio para carro.
        foreach (['Cristal perfecto' => 80, 'Calibración de llantas' => 30] as $name => $price) {
            $type = WashServiceType::create(['name' => $name, 'kind' => 'extra', 'sort_order' => 10]);
            WashService::create(['wash_service_type_id' => $type->id, 'vehicle_type_id' => $this->carro->id, 'name' => $name, 'base_price' => $price, 'is_active' => true]);
        }
    }

    public function test_extras_copy_their_kind_from_the_catalog(): void
    {
        $this->assertSame('extra', $this->cell('Cristal perfecto')->kind);
        $this->assertSame('lavado', $this->cell('Lavado general')->kind);

        $this->actingAs($this->operator, 'sanctum')
            ->getJson('/api/vehicle-types')
            ->assertOk()
            ->assertJsonFragment(['name' => 'Cristal perfecto', 'kind' => 'extra']);
    }

    public function test_wash_and_extras_are_registered_together(): void
    {
        $session = CashSession::create(['opening_amount' => 0, 'opened_at' => now()->startOfDay(), 'status' => 'abierta']);

        $response = $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $this->carro->id,
                'items' => [
                    ['wash_service_id' => $this->cell('Lavado general')->id],
                    ['wash_service_id' => $this->cell('Cristal perfecto')->id],
                    ['wash_service_id' => $this->cell('Calibración de llantas')->id],
                ],
            ])
            ->assertCreated()
            ->assertJsonCount(3, 'washes')
            ->assertJsonPath('total', 210); // 100 + 80 + 30

        $washes = Wash::all();
        $this->assertCount(3, $washes);
        $this->assertCount(1, $washes->pluck('group_uuid')->unique());
        $this->assertNotNull($washes->first()->group_uuid);
        $this->assertTrue($washes->every(fn ($w) => $w->cash_session_id === $session->id && $w->user_id === $this->operator->id));
        $this->assertSame('extra', $response->json('washes.1.wash_service.kind'));
    }

    public function test_extras_can_be_charged_without_a_wash(): void
    {
        $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $this->carro->id,
                'items' => [['wash_service_id' => $this->cell('Calibración de llantas')->id]],
            ])
            ->assertCreated()
            ->assertJsonPath('total', 30);
    }

    public function test_only_one_wash_per_vehicle(): void
    {
        $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $this->carro->id,
                'items' => [
                    ['wash_service_id' => $this->cell('Lavado general')->id],
                    ['wash_service_id' => $this->cell('Lavado con motor')->id],
                ],
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('items');

        $this->assertSame(0, Wash::count());
    }

    public function test_the_same_service_cannot_be_repeated(): void
    {
        $extra = $this->cell('Cristal perfecto')->id;

        $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $this->carro->id,
                'items' => [['wash_service_id' => $extra], ['wash_service_id' => $extra]],
            ])
            ->assertUnprocessable();
    }

    public function test_custom_price_service_needs_description_and_price_even_with_extras(): void
    {
        $otro = $this->cell('Otro');

        $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $this->carro->id,
                'items' => [['wash_service_id' => $otro->id], ['wash_service_id' => $this->cell('Cristal perfecto')->id]],
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['items.0.custom_description', 'items.0.price']);

        $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $this->carro->id,
                'items' => [
                    ['wash_service_id' => $otro->id, 'custom_description' => 'Pulido de focos', 'price' => 150],
                    ['wash_service_id' => $this->cell('Cristal perfecto')->id, 'price' => 1], // el precio del catálogo manda
                ],
            ])
            ->assertCreated()
            ->assertJsonPath('total', 230);
    }

    public function test_old_app_format_still_registers_a_single_service(): void
    {
        $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $this->carro->id,
                'wash_service_id' => $this->cell('Cristal perfecto')->id,
            ])
            ->assertCreated()
            ->assertJsonPath('price', '80.00')
            ->assertJsonPath('wash_service.name', 'Cristal perfecto');

        // Y sus errores conservan los nombres de antes.
        $this->actingAs($this->operator, 'sanctum')
            ->postJson('/api/washes', ['vehicle_type_id' => $this->carro->id, 'wash_service_id' => $this->cell('Otro')->id])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['custom_description', 'price']);
    }

    public function test_reports_count_extras_apart_but_include_their_money(): void
    {
        $this->actingAs($this->operator, 'sanctum')->postJson('/api/washes', [
            'vehicle_type_id' => $this->carro->id,
            'items' => [['wash_service_id' => $this->cell('Lavado general')->id], ['wash_service_id' => $this->cell('Cristal perfecto')->id]],
        ])->assertCreated();
        $this->actingAs($this->operator, 'sanctum')->postJson('/api/washes', [
            'vehicle_type_id' => $this->carro->id,
            'items' => [['wash_service_id' => $this->cell('Calibración de llantas')->id]],
        ])->assertCreated();

        $today = now()->toDateString();

        $this->actingAs($this->admin, 'sanctum')
            ->getJson("/api/reports/accounting?date_from={$today}&date_to={$today}")
            ->assertOk()
            ->assertJsonPath('lavados.cantidad', 1)
            ->assertJsonPath('lavados.extras', 2)
            ->assertJsonPath('lavados.por_vehiculo.0.cantidad', 1)
            ->assertJsonPath('resumen.ingresos_lavados', 210); // 100 + 80 + 30

        $this->actingAs($this->admin)
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('+ 2 extras');
    }

    public function test_panel_creates_an_extra_and_changing_its_kind_updates_every_price(): void
    {
        $this->actingAs($this->admin)
            ->post(route('admin.catalog.services.store'), ['name' => 'Aromatizante', 'kind' => 'extra', 'is_custom' => '0'])
            ->assertRedirect(route('admin.catalog.services.index'));

        $type = WashServiceType::where('name', 'Aromatizante')->firstOrFail();
        $this->assertSame('extra', $type->kind);

        $this->actingAs($this->admin)
            ->get(route('admin.catalog.services.index'))
            ->assertOk()
            ->assertSeeInOrder(['Lavados', 'Lavado general', 'Extras', 'Aromatizante']);

        $lavadoGeneral = WashServiceType::where('name', 'Lavado general')->first();
        $this->actingAs($this->admin)
            ->put(route('admin.catalog.services.update', $lavadoGeneral), ['name' => 'Lavado general', 'kind' => 'extra', 'sort_order' => 1])
            ->assertRedirect();

        $this->assertSame(3, WashService::where('wash_service_type_id', $lavadoGeneral->id)->where('kind', 'extra')->count());
    }

    private function cell(string $service, ?VehicleType $vehicle = null): WashService
    {
        return WashService::where('name', $service)
            ->where('vehicle_type_id', ($vehicle ?? $this->carro)->id)
            ->firstOrFail();
    }
}
