<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\EmployeeAdvance;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class AdvanceManagementTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_admin_can_edit_amount_of_an_advance_without_payments(): void
    {
        $advance = $this->createAdvance(500);

        $this->actingAs($this->admin(), 'sanctum')
            ->putJson("/api/advances/{$advance->id}", ['amount' => 400])
            ->assertOk()
            ->assertJsonPath('amount', '400.00')
            ->assertJsonPath('balance', '400.00')
            ->assertJsonPath('status', 'pendiente');
    }

    public function test_editing_amount_below_what_was_already_paid_is_rejected(): void
    {
        $advance = $this->createAdvance(500);
        $advance->update(['balance' => 200]); // simula L 300 ya abonados

        $this->actingAs($this->admin(), 'sanctum')
            ->putJson("/api/advances/{$advance->id}", ['amount' => 200])
            ->assertUnprocessable();
    }

    public function test_editing_amount_recalculates_balance_keeping_paid_amount(): void
    {
        $advance = $this->createAdvance(500);
        $advance->update(['balance' => 200, 'status' => 'parcialmente_pagado']); // L 300 abonados

        $this->actingAs($this->admin(), 'sanctum')
            ->putJson("/api/advances/{$advance->id}", ['amount' => 600])
            ->assertOk()
            ->assertJsonPath('amount', '600.00')
            ->assertJsonPath('balance', '300.00')
            ->assertJsonPath('status', 'parcialmente_pagado');
    }

    public function test_a_fully_paid_advance_cannot_be_edited(): void
    {
        $advance = $this->createAdvance(500);
        $advance->update(['balance' => 0, 'status' => 'pagado']);

        $this->actingAs($this->admin(), 'sanctum')
            ->putJson("/api/advances/{$advance->id}", ['amount' => 400])
            ->assertUnprocessable();
    }

    public function test_a_cancelled_advance_cannot_be_edited(): void
    {
        $advance = $this->createAdvance(500);
        $advance->update(['status' => 'anulado']);

        $this->actingAs($this->admin(), 'sanctum')
            ->putJson("/api/advances/{$advance->id}", ['amount' => 400])
            ->assertUnprocessable();
    }

    public function test_operator_cannot_edit_an_advance(): void
    {
        $advance = $this->createAdvance(500);

        $this->actingAs($this->operator(), 'sanctum')
            ->putJson("/api/advances/{$advance->id}", ['amount' => 400])
            ->assertForbidden();
    }

    private function createAdvance(float $amount): EmployeeAdvance
    {
        $employee = Employee::create([
            'first_name' => 'Juan',
            'last_name' => 'Pérez',
            'hire_date' => Carbon::parse('2026-01-01'),
            'is_active' => true,
        ]);

        return EmployeeAdvance::create([
            'employee_id' => $employee->id,
            'user_id' => $this->admin()->id,
            'amount' => $amount,
            'balance' => $amount,
            'advance_date' => Carbon::parse('2026-05-01'),
            'status' => 'pendiente',
        ]);
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
