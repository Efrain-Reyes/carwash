<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\CashSession;
use App\Models\User;
use App\Models\VehicleType;
use App\Models\Wash;
use App\Models\WashService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->withoutVite();
    }

    // ─── Acceso ──────────────────────────────────────────────────────────────

    public function test_guest_is_redirected_to_login(): void
    {
        $this->get('/admin')->assertRedirect(route('admin.login'));
        $this->get('/admin/usuarios')->assertRedirect(route('admin.login'));
    }

    public function test_api_still_returns_401_json_for_guests(): void
    {
        $this->getJson('/api/auth/me')->assertUnauthorized();
    }

    public function test_admin_can_log_in_and_see_dashboard(): void
    {
        $admin = $this->admin(['email' => 'jefe@carwash.test']);

        $this->post(route('admin.login.attempt'), ['email' => 'jefe@carwash.test', 'password' => 'password'])
            ->assertRedirect(route('admin.dashboard'));

        $this->assertAuthenticatedAs($admin);

        $this->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('Lavados hoy')
            ->assertSee('Actividad reciente');

        $this->assertDatabaseHas('audit_logs', ['user_id' => $admin->id, 'event' => 'login', 'source' => 'web']);
    }

    public function test_operator_cannot_log_in_to_panel(): void
    {
        $this->operator(['email' => 'juan@carwash.test']);

        $this->from(route('admin.login'))
            ->post(route('admin.login.attempt'), ['email' => 'juan@carwash.test', 'password' => 'password'])
            ->assertRedirect(route('admin.login'))
            ->assertSessionHasErrors(['email' => 'El panel web es solo para administradores.']);

        $this->assertGuest();
    }

    public function test_inactive_admin_cannot_log_in(): void
    {
        $this->admin(['email' => 'viejo@carwash.test', 'is_active' => false]);

        $this->post(route('admin.login.attempt'), ['email' => 'viejo@carwash.test', 'password' => 'password'])
            ->assertSessionHasErrors(['email' => 'Esta cuenta está desactivada.']);

        $this->assertGuest();
    }

    public function test_login_is_blocked_after_five_failed_attempts(): void
    {
        $this->admin(['email' => 'jefe@carwash.test']);

        foreach (range(1, 5) as $_) {
            $this->post(route('admin.login.attempt'), ['email' => 'jefe@carwash.test', 'password' => 'incorrecta']);
        }

        // Ni siquiera con la contraseña correcta entra mientras dure el bloqueo.
        $this->post(route('admin.login.attempt'), ['email' => 'jefe@carwash.test', 'password' => 'password'])
            ->assertSessionHasErrors('email');

        $this->assertGuest();
        $this->assertStringContainsString('Demasiados intentos', session('errors')->first('email'));
    }

    public function test_operator_session_is_kicked_out_of_panel(): void
    {
        $this->actingAs($this->operator())
            ->get(route('admin.dashboard'))
            ->assertRedirect(route('admin.login'));

        $this->assertGuest();
    }

    // ─── Dashboard ───────────────────────────────────────────────────────────

    public function test_dashboard_shows_open_cash_session_and_month_services(): void
    {
        $admin = $this->admin();
        $type = VehicleType::create(['name' => 'Carro', 'is_active' => true]);
        $service = WashService::create(['vehicle_type_id' => $type->id, 'name' => 'Lavado general', 'base_price' => 100, 'is_active' => true]);
        $session = CashSession::create(['opening_amount' => 500, 'opened_at' => now()->startOfDay(), 'status' => 'abierta', 'opened_by' => $admin->id]);

        Wash::create([
            'user_id' => $admin->id, 'cash_session_id' => $session->id, 'vehicle_type_id' => $type->id,
            'wash_service_id' => $service->id, 'price' => 100, 'status' => 'completado', 'registered_at' => now(),
        ]);

        $this->actingAs($admin)
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('Abierta')
            ->assertSee('Lavado general')
            ->assertSee('L 600.00'); // 500 de apertura + 100 del lavado
    }

    // ─── Usuarios ────────────────────────────────────────────────────────────

    public function test_admin_can_create_an_operator(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)
            ->post(route('admin.users.store'), [
                'name' => 'Pedro Lavador',
                'email' => 'pedro@carwash.test',
                'password' => 'clave-segura',
                'password_confirmation' => 'clave-segura',
                'role' => 'operador',
                'is_active' => '1',
            ])
            ->assertRedirect(route('admin.users.index'));

        $pedro = User::where('email', 'pedro@carwash.test')->firstOrFail();
        $this->assertTrue($pedro->hasRole('operador'));
        $this->assertTrue($pedro->is_active);

        $created = AuditLog::where('auditable_type', User::class)->where('auditable_id', $pedro->id)->where('event', 'created')->firstOrFail();
        $this->assertSame('web', $created->source);
        $this->assertSame($admin->id, $created->user_id);
        $this->assertSame('(oculto)', $created->new_values['password']);
    }

    public function test_user_form_shows_spanish_validation_errors(): void
    {
        $this->actingAs($this->admin(['email' => 'ya@existe.test']))
            ->post(route('admin.users.store'), [
                'name' => 'Duplicado',
                'email' => 'ya@existe.test',
                'password' => 'corta',
                'password_confirmation' => 'otra',
                'role' => 'operador',
            ])
            ->assertSessionHasErrors([
                'email' => 'Ya existe un usuario con ese correo.',
                'password' => 'La contraseña debe tener al menos 8 caracteres.',
            ]);
    }

    public function test_changing_role_is_logged(): void
    {
        $admin = $this->admin();
        $operator = $this->operator();

        $this->actingAs($admin)
            ->put(route('admin.users.update', $operator), [
                'name' => $operator->name,
                'email' => $operator->email,
                'role' => 'administrador',
                'is_active' => '1',
            ])
            ->assertRedirect(route('admin.users.index'));

        $this->assertTrue($operator->fresh()->hasRole('administrador'));
        $this->assertDatabaseHas('audit_logs', [
            'auditable_type' => User::class,
            'auditable_id' => $operator->id,
            'old_values' => json_encode(['rol' => 'operador']),
            'new_values' => json_encode(['rol' => 'administrador']),
        ]);
    }

    public function test_deactivating_a_user_closes_their_app_sessions(): void
    {
        $operator = $this->operator();
        $operator->createToken('mobile');

        $this->actingAs($this->admin())
            ->patch(route('admin.users.toggle', $operator))
            ->assertRedirect();

        $this->assertFalse($operator->fresh()->is_active);
        $this->assertSame(0, $operator->tokens()->count());
    }

    public function test_changing_password_closes_app_sessions(): void
    {
        $operator = $this->operator();
        $operator->createToken('mobile');

        $this->actingAs($this->admin())
            ->put(route('admin.users.update', $operator), [
                'name' => $operator->name,
                'email' => $operator->email,
                'role' => 'operador',
                'is_active' => '1',
                'password' => 'nueva-clave-123',
                'password_confirmation' => 'nueva-clave-123',
            ])
            ->assertRedirect(route('admin.users.index'));

        $this->assertSame(0, $operator->tokens()->count());
        $this->assertTrue(\Hash::check('nueva-clave-123', $operator->fresh()->password));
    }

    public function test_admin_cannot_deactivate_or_demote_themselves(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)
            ->patch(route('admin.users.toggle', $admin))
            ->assertSessionHasErrors('user');

        $this->actingAs($admin)
            ->put(route('admin.users.update', $admin), [
                'name' => $admin->name,
                'email' => $admin->email,
                'role' => 'operador',
                'is_active' => '1',
            ])
            ->assertSessionHasErrors('role');

        $this->assertTrue($admin->fresh()->is_active);
        $this->assertTrue($admin->fresh()->hasRole('administrador'));
    }

    // ─── Bitácora ────────────────────────────────────────────────────────────

    public function test_changes_from_the_app_are_logged_with_source_app(): void
    {
        $admin = $this->admin();
        $type = VehicleType::create(['name' => 'Moto', 'is_active' => true]);

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/vehicle-types/{$type->id}/toggle")
            ->assertOk();

        $log = AuditLog::where('auditable_type', VehicleType::class)->where('event', 'updated')->firstOrFail();
        $this->assertSame('app', $log->source);
        $this->assertSame($admin->id, $log->user_id);
        $this->assertEquals(['is_active' => false], $log->new_values);
        $this->assertSame('Sí', AuditLog::formatValue('is_active', $log->old_values['is_active']));
    }

    public function test_api_login_is_logged(): void
    {
        $operator = $this->operator(['email' => 'juan@carwash.test']);

        $this->postJson('/api/auth/login', ['email' => 'juan@carwash.test', 'password' => 'password'])->assertOk();

        $this->assertDatabaseHas('audit_logs', ['user_id' => $operator->id, 'event' => 'login', 'source' => 'app']);
    }

    public function test_audit_page_filters_by_module(): void
    {
        $admin = $this->admin();
        VehicleType::create(['name' => 'Camión', 'is_active' => true]);

        $this->actingAs($admin)
            ->get(route('admin.audit.index', ['module' => 'VehicleType']))
            ->assertOk()
            ->assertSee('Tipos de vehículo')
            ->assertDontSee('Usuarios <span', false);

        $this->actingAs($admin)
            ->get(route('admin.audit.index', ['module' => 'Wash']))
            ->assertOk()
            ->assertSee('No hay registros con esos filtros.');
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private function admin(array $attributes = []): User
    {
        $user = User::factory()->create(['is_active' => true, ...$attributes]);
        $user->assignRole('administrador');

        return $user;
    }

    private function operator(array $attributes = []): User
    {
        $user = User::factory()->create(['is_active' => true, ...$attributes]);
        $user->assignRole('operador');

        return $user;
    }
}
