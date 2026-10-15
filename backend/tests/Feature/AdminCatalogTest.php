<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\ExpenseCatalogItem;
use App\Models\ExpenseCategory;
use App\Models\ExpenseSupplier;
use App\Models\User;
use App\Models\VehicleType;
use App\Models\WashService;
use App\Models\WashServiceType;
use Database\Seeders\RolesAndPermissionsSeeder;
use Database\Seeders\VehicleTypeSeeder;
use Database\Seeders\WashServiceSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminCatalogTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed([RolesAndPermissionsSeeder::class, VehicleTypeSeeder::class, WashServiceSeeder::class]);
        $this->withoutVite();

        $this->admin = User::factory()->create(['is_active' => true]);
        $this->admin->assignRole('administrador');
    }

    // ─── Matriz de precios ───────────────────────────────────────────────────

    public function test_seeded_services_are_defined_once_with_a_price_per_vehicle(): void
    {
        $this->assertSame(3, WashServiceType::count()); // Lavado general, Lavado con motor, Otro
        $this->assertSame(3, $this->type('Lavado general')->prices()->count());
        $this->assertSame(2, $this->type('Lavado con motor')->prices()->count()); // la moto no tiene

        $this->actingAs($this->admin)
            ->get(route('admin.catalog.services.index'))
            ->assertOk()
            ->assertSee('Lavado con motor')
            ->assertSee('Camión')
            ->assertSee('Precio libre');
    }

    public function test_changing_one_price_only_touches_that_cell_and_is_logged(): void
    {
        $cell = $this->cell('Lavado general', 'Carro');

        $this->actingAs($this->admin)
            ->put(route('admin.catalog.services.prices'), $this->matrixPayload([$cell->id => '150']))
            ->assertRedirect(route('admin.catalog.services.index'))
            ->assertSessionHas('status', 'Se guardó 1 cambio de precio.');

        $this->assertEquals(150, $cell->fresh()->base_price);
        $this->assertEquals(70, $this->cell('Lavado general', 'Moto')->base_price);

        $log = AuditLog::where('auditable_type', WashService::class)->where('auditable_id', $cell->id)->where('event', 'updated')->firstOrFail();
        $this->assertSame('web', $log->source);
        $this->assertEquals(100, $log->old_values['base_price']);
        $this->assertEquals(150, $log->new_values['base_price']);
    }

    public function test_saving_the_matrix_without_changes_reports_nothing_changed(): void
    {
        $this->actingAs($this->admin)
            ->put(route('admin.catalog.services.prices'), $this->matrixPayload())
            ->assertSessionHas('status', 'No hubo cambios en los precios.');
    }

    public function test_empty_price_stops_offering_the_service_without_deleting_it(): void
    {
        $cell = $this->cell('Lavado con motor', 'Carro');

        $this->actingAs($this->admin)
            ->put(route('admin.catalog.services.prices'), $this->matrixPayload([$cell->id => '']));

        $this->assertDatabaseHas('wash_services', ['id' => $cell->id, 'is_active' => false]);

        $carro = collect($this->actingAs($this->admin, 'sanctum')->getJson('/api/vehicle-types')->json())->firstWhere('name', 'Carro');
        $this->assertNotContains('Lavado con motor', array_column($carro['wash_services'], 'name'));

        $this->actingAs($this->admin, 'sanctum')
            ->postJson('/api/washes', ['vehicle_type_id' => $cell->vehicle_type_id, 'wash_service_id' => $cell->id])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('wash_service_id');
    }

    public function test_filling_an_empty_cell_offers_the_service_for_that_vehicle(): void
    {
        $moto = VehicleType::where('name', 'Moto')->first();
        $type = $this->type('Lavado con motor');

        $payload = $this->matrixPayload();
        $payload['prices'][$type->id][$moto->id] = '95.50';

        $this->actingAs($this->admin)->put(route('admin.catalog.services.prices'), $payload);

        $cell = WashService::where('wash_service_type_id', $type->id)->where('vehicle_type_id', $moto->id)->firstOrFail();
        $this->assertEquals(95.5, $cell->base_price);
        $this->assertSame('Lavado con motor', $cell->name);

        // La app lo ve y puede registrar un lavado con él, al precio del catálogo.
        $this->actingAs($this->admin, 'sanctum')
            ->postJson('/api/washes', ['vehicle_type_id' => $moto->id, 'wash_service_id' => $cell->id])
            ->assertCreated()
            ->assertJsonPath('price', '95.50');
    }

    public function test_custom_service_is_offered_with_a_checkbox(): void
    {
        $cell = $this->cell('Otro', 'Moto');
        $payload = $this->matrixPayload();
        $payload['offered'][$cell->wash_service_type_id][$cell->vehicle_type_id] = '0';

        $this->actingAs($this->admin)->put(route('admin.catalog.services.prices'), $payload);

        $this->assertFalse($cell->fresh()->is_active);
        $this->assertNull($cell->fresh()->base_price);
    }

    public function test_negative_price_is_rejected_and_nothing_changes(): void
    {
        $cell = $this->cell('Lavado general', 'Carro');

        $this->actingAs($this->admin)
            ->put(route('admin.catalog.services.prices'), $this->matrixPayload([$cell->id => '-5']))
            ->assertSessionHasErrors("prices.{$cell->wash_service_type_id}.{$cell->vehicle_type_id}");

        $this->assertEquals(100, $cell->fresh()->base_price);
    }

    // ─── Servicios del catálogo ──────────────────────────────────────────────

    public function test_admin_creates_a_service_and_renaming_it_updates_every_vehicle(): void
    {
        $this->actingAs($this->admin)
            ->post(route('admin.catalog.services.store'), ['name' => 'Encerado', 'kind' => 'lavado', 'is_custom' => '0', 'sort_order' => 4])
            ->assertRedirect(route('admin.catalog.services.index'));

        $type = $this->type('Encerado');
        $this->assertFalse($type->is_custom);

        $payload = $this->matrixPayload();
        foreach (VehicleType::all() as $vehicle) {
            $payload['prices'][$type->id][$vehicle->id] = '200';
        }
        $this->actingAs($this->admin)->put(route('admin.catalog.services.prices'), $payload);
        $this->assertSame(3, $type->prices()->where('is_active', true)->count());

        $this->actingAs($this->admin)
            ->put(route('admin.catalog.services.update', $type), ['name' => 'Encerado premium', 'kind' => 'lavado', 'sort_order' => 4])
            ->assertRedirect();

        $this->assertSame(3, WashService::where('name', 'Encerado premium')->count());
        $this->assertSame(0, WashService::where('name', 'Encerado')->count());
    }

    public function test_service_names_must_be_unique(): void
    {
        $this->actingAs($this->admin)
            ->post(route('admin.catalog.services.store'), ['name' => 'lavado general', 'kind' => 'lavado'])
            ->assertSessionHasErrors(['name' => 'Ya existe un registro con ese nombre.']);
    }

    public function test_deactivating_a_service_hides_it_for_every_vehicle_in_the_app(): void
    {
        $type = $this->type('Lavado con motor');

        $this->actingAs($this->admin)->patch(route('admin.catalog.services.toggle', $type));

        $this->assertFalse($type->fresh()->is_active);
        $services = collect($this->actingAs($this->admin, 'sanctum')->getJson('/api/vehicle-types')->json())
            ->flatMap(fn ($v) => array_column($v['wash_services'], 'name'));
        $this->assertNotContains('Lavado con motor', $services);

        // Sus precios se conservan para cuando se reactive.
        $this->assertSame(2, $type->prices()->where('is_active', true)->count());
    }

    // ─── Tipos de vehículo ───────────────────────────────────────────────────

    public function test_admin_creates_a_vehicle_type_with_icon_and_order(): void
    {
        $this->actingAs($this->admin)
            ->post(route('admin.catalog.vehicles.store'), ['name' => 'Pick-up', 'icon' => 'pickup', 'sort_order' => 2, 'is_active' => '1'])
            ->assertRedirect(route('admin.catalog.services.index'));

        $this->assertDatabaseHas('vehicle_types', ['name' => 'Pick-up', 'icon' => 'pickup', 'sort_order' => 2]);

        // La app recibe el icono y respeta el orden (Carro=1, Pick-up=2, Moto=2, Camión=3; empate por id).
        $this->actingAs($this->admin, 'sanctum')
            ->getJson('/api/vehicle-types')
            ->assertJsonPath('0.name', 'Carro')
            ->assertJsonPath('1.name', 'Moto')
            ->assertJsonPath('2.name', 'Pick-up')
            ->assertJsonPath('2.icon', 'pickup');
    }

    public function test_vehicle_type_validation_is_in_spanish(): void
    {
        $this->actingAs($this->admin)
            ->post(route('admin.catalog.vehicles.store'), ['name' => 'Carro', 'icon' => 'cohete'])
            ->assertSessionHasErrors([
                'name' => 'Ya existe un registro con ese nombre.',
                'icon' => 'Selecciona un icono válido.',
            ]);
    }

    public function test_vehicle_types_page_lists_them(): void
    {
        $this->actingAs($this->admin)
            ->get(route('admin.catalog.vehicles.index'))
            ->assertOk()
            ->assertSee('Camión')
            ->assertSee('🏍️');
    }

    // ─── Proveedores y gastos ────────────────────────────────────────────────

    public function test_admin_manages_suppliers(): void
    {
        $this->actingAs($this->admin)
            ->post(route('admin.catalog.suppliers.store'), ['name' => 'Ferretería El Pino', 'contact' => '9999-0000', 'is_active' => '1'])
            ->assertRedirect(route('admin.catalog.suppliers.index'));

        $supplier = ExpenseSupplier::where('name', 'Ferretería El Pino')->firstOrFail();

        $this->actingAs($this->admin)->patch(route('admin.catalog.suppliers.toggle', $supplier));
        $this->assertFalse($supplier->fresh()->is_active);

        $this->actingAs($this->admin)
            ->get(route('admin.catalog.suppliers.index', ['buscar' => 'pino']))
            ->assertOk()
            ->assertSee('Ferretería El Pino');
    }

    public function test_expense_categories_replace_the_fixed_list(): void
    {
        $this->assertSame(['Producto', 'Insumo', 'Servicio'], ExpenseCategory::ordered()->pluck('name')->all());

        $this->actingAs($this->admin)
            ->post(route('admin.catalog.expense-categories.store'), ['name' => 'Servicios públicos', 'sort_order' => 4, 'is_active' => '1'])
            ->assertRedirect(route('admin.catalog.expense-categories.index'));

        $category = ExpenseCategory::where('name', 'Servicios públicos')->firstOrFail();

        $this->actingAs($this->admin)
            ->post(route('admin.catalog.expense-items.store'), [
                'name' => 'Recibo de agua', 'expense_category_id' => $category->id,
                'base_price' => '450', 'tax_rate' => '0', 'is_active' => '1',
            ])
            ->assertRedirect(route('admin.catalog.expense-items.index'));

        $this->assertDatabaseHas('expense_catalog_items', ['name' => 'Recibo de agua', 'expense_category_id' => $category->id]);

        $this->actingAs($this->admin, 'sanctum')
            ->getJson('/api/catalog-items')
            ->assertOk()
            ->assertJsonPath('0.category.name', 'Servicios públicos');

        $this->actingAs($this->admin)
            ->get(route('admin.catalog.expense-items.index', ['categoria' => $category->id]))
            ->assertOk()
            ->assertSee('Recibo de agua');
    }

    public function test_expense_item_requires_a_category(): void
    {
        $this->actingAs($this->admin)
            ->post(route('admin.catalog.expense-items.store'), ['name' => 'Jabón'])
            ->assertSessionHasErrors(['expense_category_id' => 'El campo categoría es obligatorio.']);

        $this->assertSame(0, ExpenseCatalogItem::count());
    }

    // ─── Acceso y compatibilidad con la app ──────────────────────────────────

    public function test_operator_cannot_open_catalog_pages(): void
    {
        $operator = User::factory()->create(['is_active' => true]);
        $operator->assignRole('operador');

        $this->actingAs($operator)
            ->get(route('admin.catalog.services.index'))
            ->assertRedirect(route('admin.login'));
    }

    public function test_app_keeps_creating_services_per_vehicle_and_reuses_the_catalog(): void
    {
        $moto = VehicleType::where('name', 'Moto')->first();

        $this->actingAs($this->admin, 'sanctum')
            ->postJson('/api/wash-services', ['vehicle_type_id' => $moto->id, 'name' => 'lavado con motor', 'is_custom' => false, 'base_price' => 90])
            ->assertCreated()
            ->assertJsonPath('name', 'Lavado con motor')
            ->assertJsonPath('base_price', '90.00');

        $this->assertSame(3, WashServiceType::count()); // no se duplicó el servicio

        $this->actingAs($this->admin, 'sanctum')
            ->postJson('/api/wash-services', ['vehicle_type_id' => $moto->id, 'name' => 'Lavado con motor', 'is_custom' => false, 'base_price' => 90])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('name');
    }

    public function test_renaming_from_the_app_renames_the_service_for_all_vehicles(): void
    {
        $cell = $this->cell('Lavado general', 'Moto');

        $this->actingAs($this->admin, 'sanctum')
            ->patchJson("/api/wash-services/{$cell->id}", ['name' => 'Lavado básico', 'base_price' => 75])
            ->assertOk()
            ->assertJsonPath('name', 'Lavado básico')
            ->assertJsonPath('base_price', '75.00');

        $this->assertSame(3, WashService::where('name', 'Lavado básico')->count());
        $this->assertEquals(100, $this->cell('Lavado básico', 'Carro')->base_price); // solo cambió el precio de la moto
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private function type(string $name): WashServiceType
    {
        return WashServiceType::where('name', $name)->firstOrFail();
    }

    private function cell(string $service, string $vehicle): WashService
    {
        return WashService::where('name', $service)
            ->whereHas('vehicleType', fn ($q) => $q->where('name', $vehicle))
            ->firstOrFail();
    }

    /** Lo que envía la matriz tal cual está, con cambios opcionales [wash_service_id => precio]. */
    private function matrixPayload(array $overrides = []): array
    {
        $payload = ['prices' => [], 'offered' => []];

        foreach (WashService::with('serviceType')->get() as $cell) {
            if ($cell->serviceType->is_custom) {
                $payload['offered'][$cell->wash_service_type_id][$cell->vehicle_type_id] = $cell->is_active ? '1' : '0';
            } else {
                $price = array_key_exists($cell->id, $overrides) ? $overrides[$cell->id] : ($cell->is_active ? $cell->base_price : '');
                $payload['prices'][$cell->wash_service_type_id][$cell->vehicle_type_id] = $price;
            }
        }

        return $payload;
    }
}
