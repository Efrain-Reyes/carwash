<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use App\Services\AuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class UserController extends Controller
{
    public const ROLES = [
        'administrador' => 'Administrador',
        'operador'      => 'Operador',
    ];

    private const MESSAGES = [
        'required'  => 'El campo :attribute es obligatorio.',
        'email'     => 'Escribe un correo válido.',
        'unique'    => 'Ya existe un usuario con ese :attribute.',
        'min'       => 'La :attribute debe tener al menos :min caracteres.',
        'max'       => 'El campo :attribute es demasiado largo.',
        'confirmed' => 'Las contraseñas no coinciden.',
        'in'        => 'Selecciona un :attribute válido.',
    ];

    private const ATTRIBUTES = [
        'name'     => 'nombre',
        'email'    => 'correo',
        'password' => 'contraseña',
        'role'     => 'rol',
    ];

    public function index(): View
    {
        $users = User::with('roles')
            // Último inicio de sesión (app o panel), sacado de la bitácora.
            ->addSelect(['last_login_at' => AuditLog::select('created_at')
                ->whereColumn('user_id', 'users.id')
                ->where('event', 'login')
                ->latest('created_at')
                ->limit(1),
            ])
            ->withCasts(['last_login_at' => 'datetime'])
            ->orderByDesc('is_active')
            ->orderBy('name')
            ->get();

        return view('admin.users.index', ['users' => $users, 'roles' => self::ROLES]);
    }

    public function create(): View
    {
        return view('admin.users.form', ['user' => new User(['is_active' => true]), 'roles' => self::ROLES]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name'      => 'required|string|max:100',
            'email'     => 'required|email|max:150|unique:users,email',
            'password'  => 'required|string|min:8|confirmed',
            'role'      => ['required', Rule::in(array_keys(self::ROLES))],
            'is_active' => 'boolean',
        ], self::MESSAGES, self::ATTRIBUTES);

        $user = User::create([
            'name'      => $data['name'],
            'email'     => $data['email'],
            'password'  => $data['password'],
            'is_active' => $request->boolean('is_active'),
        ]);

        $user->assignRole($data['role']);
        AuditLogger::record('updated', $user, ['rol' => null], ['rol' => $data['role']]);

        return redirect()->route('admin.users.index')
            ->with('status', "Usuario {$user->name} creado.");
    }

    public function edit(User $user): View
    {
        return view('admin.users.form', ['user' => $user, 'roles' => self::ROLES]);
    }

    public function update(Request $request, User $user): RedirectResponse
    {
        $data = $request->validate([
            'name'      => 'required|string|max:100',
            'email'     => ['required', 'email', 'max:150', Rule::unique('users', 'email')->ignore($user->id)],
            'password'  => 'nullable|string|min:8|confirmed',
            'role'      => ['required', Rule::in(array_keys(self::ROLES))],
            'is_active' => 'boolean',
        ], self::MESSAGES, self::ATTRIBUTES);

        $isActive = $request->boolean('is_active');

        if ($user->is($request->user()) && (! $isActive || $data['role'] !== 'administrador')) {
            throw ValidationException::withMessages([
                'role' => 'No puedes quitarte el rol de administrador ni desactivar tu propia cuenta.',
            ]);
        }

        $user->fill([
            'name'      => $data['name'],
            'email'     => $data['email'],
            'is_active' => $isActive,
        ]);

        if (! empty($data['password'])) {
            $user->password = $data['password'];
        }

        $passwordChanged = $user->isDirty('password');
        $deactivated = $user->isDirty('is_active') && ! $isActive;

        $user->save();

        $currentRole = $user->getRoleNames()->first();
        if ($currentRole !== $data['role']) {
            $user->syncRoles([$data['role']]);
            AuditLogger::record('updated', $user, ['rol' => $currentRole], ['rol' => $data['role']]);
        }

        // Cierra las sesiones de la app si cambió la contraseña o se desactivó la cuenta.
        if ($passwordChanged || $deactivated) {
            $user->tokens()->delete();
        }

        return redirect()->route('admin.users.index')
            ->with('status', "Usuario {$user->name} actualizado.");
    }

    public function toggle(Request $request, User $user): RedirectResponse
    {
        if ($user->is($request->user())) {
            return back()->withErrors(['user' => 'No puedes desactivar tu propia cuenta.']);
        }

        $user->update(['is_active' => ! $user->is_active]);

        if (! $user->is_active) {
            $user->tokens()->delete();
        }

        return back()->with('status', $user->is_active
            ? "{$user->name} fue activado."
            : "{$user->name} fue desactivado y se cerraron sus sesiones en la app.");
    }
}
