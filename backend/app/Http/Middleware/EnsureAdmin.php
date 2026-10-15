<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Solo deja pasar al panel web a usuarios activos con rol administrador.
 * Si a alguien le quitan el rol o lo desactivan, su sesión se cierra en la siguiente petición.
 */
class EnsureAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->is_active || ! $user->hasRole('administrador')) {
            Auth::guard('web')->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('admin.login')
                ->withErrors(['email' => 'Tu cuenta no tiene acceso al panel.']);
        }

        return $next($request);
    }
}
