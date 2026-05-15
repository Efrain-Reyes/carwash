<?php

use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

return new class extends Migration
{
    public function up(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $cashView = Permission::firstOrCreate(['name' => 'cash.view']);
        $cashManage = Permission::firstOrCreate(['name' => 'cash.manage']);

        $admin = Role::firstOrCreate(['name' => 'administrador']);
        $admin->givePermissionTo([$cashView, $cashManage]);

        $operator = Role::firstOrCreate(['name' => 'operador']);
        $operator->givePermissionTo($cashView);

        User::role('administrador')->each(
            fn (User $user) => $user->givePermissionTo([$cashView, $cashManage])
        );

        User::role('operador')->each(
            fn (User $user) => $user->givePermissionTo($cashView)
        );

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    public function down(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $cashPermissions = ['cash.view', 'cash.manage'];

        Role::query()->each(
            fn (Role $role) => $role->revokePermissionTo($cashPermissions)
        );

        User::query()->each(
            fn (User $user) => $user->revokePermissionTo($cashPermissions)
        );

        Permission::whereIn('name', $cashPermissions)->delete();

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }
};
