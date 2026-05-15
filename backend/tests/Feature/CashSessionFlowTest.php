<?php

namespace Tests\Feature;

use App\Models\CashSession;
use App\Models\User;
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
        CashSession::create([
            'opening_amount' => 100,
            'expected_closing_amount' => 125,
            'counted_closing_amount' => 110,
            'difference' => -15,
            'opened_at' => Carbon::parse('2026-05-14 00:00:00', config('app.timezone')),
            'closed_at' => Carbon::parse('2026-05-14 23:00:00', config('app.timezone')),
            'status' => 'cerrada',
            'notes' => 'Cierre anterior',
        ]);

        $response = $this->actingAs($this->operator(), 'sanctum')
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

    public function test_operator_can_view_current_cash_but_cannot_open_or_close(): void
    {
        $operator = $this->operator();
        $session = CashSession::create([
            'opening_amount' => 200,
            'opened_at' => Carbon::parse('2026-05-15 08:00:00', config('app.timezone')),
            'status' => 'abierta',
        ]);

        $this->actingAs($operator, 'sanctum')
            ->getJson('/api/cash-sessions/current')
            ->assertOk()
            ->assertJsonPath('cash_session.id', $session->id);

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
