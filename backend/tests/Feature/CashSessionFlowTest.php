<?php

namespace Tests\Feature;

use App\Models\CashSession;
use App\Models\ExpenseSupplier;
use App\Models\User;
use App\Models\VehicleType;
use App\Models\Wash;
use App\Models\WashService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class CashSessionFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Carbon::setTestNow(Carbon::parse('2026-05-15 09:00:00', config('app.timezone')));
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_current_requires_first_cash_session_when_no_previous_cash_exists(): void
    {
        $response = $this->actingAs($this->admin(), 'sanctum')
            ->getJson('/api/cash-sessions/current');

        $response
            ->assertOk()
            ->assertJsonPath('cash_session', null)
            ->assertJsonPath('requires_first_cash_session', true)
            ->assertJsonPath('pending_closure', false);
    }

    public function test_admin_can_create_only_the_first_manual_cash_session(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/cash-sessions', [
                'opening_amount' => 350,
                'notes' => 'Inicio manual',
            ])
            ->assertCreated()
            ->assertJsonPath('cash_session.opening_amount', 350);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/cash-sessions', [
                'opening_amount' => 500,
            ])
            ->assertUnprocessable();

        $this->assertDatabaseCount('cash_sessions', 1);
    }

    public function test_report_returns_cash_section_when_cash_exists_in_selected_range(): void
    {
        $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/cash-sessions', [
                'opening_amount' => 350,
            ])
            ->assertCreated();

        $this->actingAs($this->admin(), 'sanctum')
            ->getJson('/api/reports/accounting?date_from=2026-05-15&date_to=2026-05-15')
            ->assertOk()
            ->assertJsonPath('caja.status', 'abierta')
            ->assertJsonPath('caja.saldo_inicial_caja', 350)
            ->assertJsonPath('caja.movimiento_neto_efectivo', 0)
            ->assertJsonPath('caja.saldo_final_estimado', 350);
    }

    public function test_current_opens_today_from_last_counted_closing_amount(): void
    {
        $session = CashSession::create([
            'opening_amount' => 100,
            'expected_closing_amount' => 125,
            'counted_closing_amount' => 110,
            'difference' => -15,
            'opened_at' => Carbon::parse('2026-05-14 00:00:00', config('app.timezone')),
            'closed_at' => Carbon::parse('2026-05-14 23:00:00', config('app.timezone')),
            'status' => 'cerrada',
            'notes' => 'Cierre anterior',
        ]);

        $response = $this->actingAs($this->admin(), 'sanctum')
            ->getJson('/api/cash-sessions/current');

        $response
            ->assertOk()
            ->assertJsonPath('opened_automatically', true)
            ->assertJsonPath('cash_session.opening_amount', 110)
            ->assertJsonPath('cash_session.status', 'abierta')
            ->assertJsonPath('cash_session.opened_by', null)
            ->assertJsonPath('cash_session.notes', 'Caja abierta automáticamente desde el cierre anterior');

        $this->assertDatabaseHas('cash_sessions', [
            'opening_amount' => 110,
            'status' => 'abierta',
            'opened_by' => null,
            'notes' => 'Caja abierta automáticamente desde el cierre anterior',
        ]);
    }

    public function test_current_does_not_create_when_previous_day_cash_is_still_open(): void
    {
        $session = CashSession::create([
            'opening_amount' => 200,
            'opened_at' => Carbon::parse('2026-05-14 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        $response = $this->actingAs($this->admin(), 'sanctum')
            ->getJson('/api/cash-sessions/current');

        $response
            ->assertOk()
            ->assertJsonPath('pending_closure', true)
            ->assertJsonPath('message', 'Hay una caja pendiente de cierre.')
            ->assertJsonPath('cash_session.id', $session->id);

        $this->assertDatabaseCount('cash_sessions', 1);
    }

    public function test_operator_cannot_view_or_manage_cash(): void
    {
        $operator = $this->operator();
        $session = CashSession::create([
            'opening_amount' => 200,
            'opened_at' => Carbon::parse('2026-05-15 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        $this->actingAs($operator, 'sanctum')
            ->getJson('/api/cash-sessions/current')
            ->assertForbidden();

        $this->actingAs($operator, 'sanctum')
            ->postJson('/api/cash-sessions', ['opening_amount' => 100])
            ->assertForbidden();

        $this->actingAs($operator, 'sanctum')
            ->patchJson("/api/cash-sessions/{$session->id}/close", [
                'counted_closing_amount' => 210,
            ])
            ->assertForbidden();
    }

    public function test_admin_close_calculates_difference_from_counted_cash(): void
    {
        $session = CashSession::create([
            'opening_amount' => 200,
            'opened_at' => Carbon::parse('2026-05-15 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        $this->actingAs($this->admin(), 'sanctum')
            ->patchJson("/api/cash-sessions/{$session->id}/close", [
                'counted_closing_amount' => 185,
                'notes' => 'Faltante revisado',
            ])
            ->assertOk()
            ->assertJsonPath('cash_session.expected_closing_amount', 200)
            ->assertJsonPath('cash_session.counted_closing_amount', 185)
            ->assertJsonPath('cash_session.difference', -15)
            ->assertJsonPath('cash_session.notes', 'Faltante revisado');
    }

    public function test_admin_can_adjust_closed_cash_session_and_update_next_opening_cash(): void
    {
        $admin = $this->admin();
        $closed = CashSession::create([
            'opening_amount' => 100,
            'expected_closing_amount' => 100,
            'counted_closing_amount' => 100,
            'difference' => 0,
            'opened_at' => Carbon::parse('2026-05-14 08:00:00', config('app.timezone')),
            'closed_at' => Carbon::parse('2026-05-14 20:00:00', config('app.timezone')),
            'status' => 'cerrada',
            'notes' => 'Cierre original',
        ]);
        $nextOpen = CashSession::create([
            'opening_amount' => 100,
            'opened_at' => Carbon::parse('2026-05-15 00:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/cash-sessions/{$closed->id}/closing-adjustment", [
                'counted_closing_amount' => 150,
                'notes' => 'Conteo corregido',
                'reason' => 'Se contó el total físico de caja.',
            ])
            ->assertOk()
            ->assertJsonPath('cash_session.counted_closing_amount', 150)
            ->assertJsonPath('cash_session.difference', 50)
            ->assertJsonPath('next_session_updated', true)
            ->assertJsonPath('warning', null);

        $this->assertDatabaseHas('cash_session_adjustments', [
            'cash_session_id' => $closed->id,
            'user_id' => $admin->id,
            'old_counted_closing_amount' => 100,
            'new_counted_closing_amount' => 150,
            'old_difference' => 0,
            'new_difference' => 50,
            'old_notes' => 'Cierre original',
            'new_notes' => 'Conteo corregido',
            'reason' => 'Se contó el total físico de caja.',
        ]);

        $this->assertDatabaseHas('cash_sessions', [
            'id' => $nextOpen->id,
            'opening_amount' => 150,
            'expected_closing_amount' => 150,
        ]);
    }

    public function test_adjustment_does_not_silently_update_next_closed_cash_session(): void
    {
        $closed = CashSession::create([
            'opening_amount' => 100,
            'expected_closing_amount' => 100,
            'counted_closing_amount' => 100,
            'difference' => 0,
            'opened_at' => Carbon::parse('2026-05-13 08:00:00', config('app.timezone')),
            'closed_at' => Carbon::parse('2026-05-13 20:00:00', config('app.timezone')),
            'status' => 'cerrada',
        ]);
        $nextClosed = CashSession::create([
            'opening_amount' => 100,
            'expected_closing_amount' => 120,
            'counted_closing_amount' => 120,
            'difference' => 0,
            'opened_at' => Carbon::parse('2026-05-14 08:00:00', config('app.timezone')),
            'closed_at' => Carbon::parse('2026-05-14 20:00:00', config('app.timezone')),
            'status' => 'cerrada',
        ]);

        $this->actingAs($this->admin(), 'sanctum')
            ->patchJson("/api/cash-sessions/{$closed->id}/closing-adjustment", [
                'counted_closing_amount' => 140,
                'notes' => 'Ajuste controlado',
                'reason' => 'Corrección de cierre anterior.',
            ])
            ->assertOk()
            ->assertJsonPath('next_session_updated', false)
            ->assertJsonPath('warning', 'Existe una caja posterior ya cerrada. No se modificó la cadena automáticamente; revise el historial y registre los ajustes necesarios con evidencia.');

        $this->assertDatabaseHas('cash_sessions', [
            'id' => $nextClosed->id,
            'opening_amount' => 100,
            'expected_closing_amount' => 120,
        ]);
    }

    /**
     * Reproduce el bug reportado: una caja se cierra el lunes, se abre otra el
     * martes, y el usuario no cierra caja en toda la semana. El viernes registra
     * en el sistema un lavado que ocurrió el lunes (registered_at pasado). Antes
     * del fix, ese lavado quedaba fuera del rango [martes → viernes] de la sesión
     * abierta y nunca se contabilizaba en ningún cierre. Con el fix, el lavado se
     * sella con la sesión abierta al momento de crearse (la de martes), así que
     * SIEMPRE se cuenta en el cierre de esa sesión sin importar su registered_at.
     */
    public function test_wash_registered_late_is_included_in_the_currently_open_session_closing(): void
    {
        [$vehicleType, $service] = $this->vehicleAndService();
        $operator = $this->operator();

        // Lunes: se abre y se cierra la primera caja normalmente.
        Carbon::setTestNow(Carbon::parse('2026-05-11 08:00:00', config('app.timezone')));
        $monday = CashSession::create([
            'opening_amount' => 100,
            'opened_at' => Carbon::parse('2026-05-11 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        $this->actingAs($this->admin(), 'sanctum')
            ->patchJson("/api/cash-sessions/{$monday->id}/close", [
                'counted_closing_amount' => 100,
            ])
            ->assertOk();

        // Martes: se abre la siguiente caja (sesión que quedará abierta toda la semana).
        Carbon::setTestNow(Carbon::parse('2026-05-12 08:00:00', config('app.timezone')));
        $tuesday = CashSession::create([
            'opening_amount' => 100,
            'opened_at' => Carbon::parse('2026-05-12 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        // Viernes: el operador registra en el sistema un lavado que ocurrió el lunes.
        Carbon::setTestNow(Carbon::parse('2026-05-15 09:00:00', config('app.timezone')));
        $this->actingAs($operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $vehicleType->id,
                'wash_service_id' => $service->id,
                'registered_at' => '2026-05-11 10:00:00',
            ])
            ->assertCreated();

        // El lavado atrasado debe quedar sellado a la sesión que estaba abierta
        // cuando se registró (martes), no a la del lunes (ya cerrada).
        $this->assertDatabaseHas('washes', [
            'cash_session_id' => $tuesday->id,
            'price' => 250,
        ]);

        // Un lavado normal de esta misma semana también debe sumar.
        $this->actingAs($operator, 'sanctum')
            ->postJson('/api/washes', [
                'vehicle_type_id' => $vehicleType->id,
                'wash_service_id' => $service->id,
            ])
            ->assertCreated();

        // Al cerrar la caja del viernes, el total debe incluir AMBOS lavados (250 + 250 = 500),
        // no solo el de hoy. Antes del fix, este total daba 250 (el atrasado se perdía).
        $this->actingAs($this->admin(), 'sanctum')
            ->patchJson("/api/cash-sessions/{$tuesday->id}/close", [
                'counted_closing_amount' => 600,
            ])
            ->assertOk()
            ->assertJsonPath('cash_session.expected_closing_amount', 600)
            ->assertJsonPath('movimiento.ingresos_lavados', 500);
    }

    /**
     * Un lavado huérfano legacy (cash_session_id nulo, como los que existían antes
     * del fix) debe ser reclamado y contabilizado por el próximo cierre real,
     * gracias a la red de seguridad en AccountingReportService::washesQuery().
     */
    public function test_orphan_wash_without_cash_session_is_claimed_by_the_next_closing(): void
    {
        [$vehicleType, $service] = $this->vehicleAndService();

        Carbon::setTestNow(Carbon::parse('2026-05-12 08:00:00', config('app.timezone')));
        $session = CashSession::create([
            'opening_amount' => 100,
            'opened_at' => Carbon::parse('2026-05-12 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        // Simula un lavado huérfano (dato legacy anterior al fix, cash_session_id nulo).
        Wash::create([
            'user_id' => $this->operator()->id,
            'cash_session_id' => null,
            'vehicle_type_id' => $vehicleType->id,
            'wash_service_id' => $service->id,
            'price' => 250,
            'status' => 'completado',
            'registered_at' => Carbon::parse('2026-05-10 10:00:00', config('app.timezone')),
        ]);

        Carbon::setTestNow(Carbon::parse('2026-05-15 09:00:00', config('app.timezone')));

        $this->actingAs($this->admin(), 'sanctum')
            ->patchJson("/api/cash-sessions/{$session->id}/close", [
                'counted_closing_amount' => 350,
            ])
            ->assertOk()
            ->assertJsonPath('movimiento.ingresos_lavados', 250);

        $this->assertDatabaseHas('washes', [
            'cash_session_id' => $session->id,
            'price' => 250,
        ]);
    }

    /**
     * Mismo patrón del bug de lavados, aplicado a gastos: un gasto registrado con
     * fecha atrasada (de una sesión ya cerrada) debe sumarse al cierre de la
     * sesión que está abierta cuando se captura en el sistema, no perderse.
     */
    public function test_expense_registered_late_is_included_in_the_currently_open_session_closing(): void
    {
        $supplier = ExpenseSupplier::create(['name' => 'Proveedor X', 'is_active' => true]);
        $admin = $this->admin();

        Carbon::setTestNow(Carbon::parse('2026-05-11 08:00:00', config('app.timezone')));
        $monday = CashSession::create([
            'opening_amount' => 100,
            'opened_at' => Carbon::parse('2026-05-11 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);
        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/cash-sessions/{$monday->id}/close", ['counted_closing_amount' => 100])
            ->assertOk();

        Carbon::setTestNow(Carbon::parse('2026-05-12 08:00:00', config('app.timezone')));
        $tuesday = CashSession::create([
            'opening_amount' => 100,
            'opened_at' => Carbon::parse('2026-05-12 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        // El viernes se registra un gasto que ocurrió el lunes.
        Carbon::setTestNow(Carbon::parse('2026-05-15 09:00:00', config('app.timezone')));
        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/expenses', [
                'supplier_id' => $supplier->id,
                'is_internal_invoice' => true,
                'expense_date' => '2026-05-11 10:00:00',
                'items' => [
                    ['description' => 'Jabón', 'quantity' => 1, 'unit_price' => 80],
                ],
            ])
            ->assertCreated();

        $this->assertDatabaseHas('expenses', [
            'cash_session_id' => $tuesday->id,
            'total' => 80,
        ]);

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/cash-sessions/{$tuesday->id}/close", ['counted_closing_amount' => 20])
            ->assertOk()
            ->assertJsonPath('movimiento.total_gastos', 80);
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
