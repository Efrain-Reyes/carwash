<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\AuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class AuthController extends Controller
{
    public function showLogin(): View|RedirectResponse
    {
        if (Auth::check()) {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.auth.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email'    => 'required|email',
            'password' => 'required|string',
        ], [
            'email.required'    => 'Escribe tu correo.',
            'email.email'       => 'Escribe un correo válido.',
            'password.required' => 'Escribe tu contraseña.',
        ]);

        // Máximo 5 intentos fallidos por minuto para el mismo correo desde la misma IP.
        $throttleKey = Str::lower($credentials['email']).'|'.$request->ip();

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            throw ValidationException::withMessages([
                'email' => 'Demasiados intentos. Espera '.RateLimiter::availableIn($throttleKey).' segundos e intenta de nuevo.',
            ]);
        }

        if (! Auth::attempt($credentials, $request->boolean('remember'))) {
            RateLimiter::hit($throttleKey, 60);

            throw ValidationException::withMessages([
                'email' => 'Las credenciales no son correctas.',
            ]);
        }

        RateLimiter::clear($throttleKey);

        $user = Auth::user();

        if (! $user->is_active || ! $user->hasRole('administrador')) {
            Auth::logout();

            throw ValidationException::withMessages([
                'email' => $user->is_active
                    ? 'El panel web es solo para administradores.'
                    : 'Esta cuenta está desactivada.',
            ]);
        }

        // Nuevo id de sesión al iniciar sesión para evitar fijación de sesión.
        $request->session()->regenerate();

        AuditLogger::record('login', $user);

        return redirect()->intended(route('admin.dashboard'));
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
