<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>Iniciar sesión · Jin Carwash</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="grid min-h-screen place-items-center bg-brand-900 px-4 py-10 font-sans text-ink antialiased">

    <div class="w-full max-w-sm">
        <div class="mb-8 text-center text-white">
            <span class="mx-auto grid size-14 place-items-center rounded-2xl bg-accent-500 text-2xl font-extrabold shadow-lg shadow-accent-500/30">J</span>
            <h1 class="mt-4 text-2xl font-extrabold tracking-tight">Jin Carwash</h1>
            <p class="mt-1 text-sm text-white/60">Panel administrativo</p>
        </div>

        <form method="POST" action="{{ route('admin.login.attempt') }}" class="card space-y-5 p-6 sm:p-7">
            @csrf

            @if ($errors->any())
                <div class="rounded-xl bg-bad-bg px-4 py-3 text-sm font-medium text-bad-fg" role="alert">
                    {{ $errors->first() }}
                </div>
            @endif

            <div>
                <label for="email" class="field-label">Correo</label>
                <input id="email" name="email" type="email" value="{{ old('email') }}" required autofocus autocomplete="username" class="field">
            </div>

            <div>
                <label for="password" class="field-label">Contraseña</label>
                <input id="password" name="password" type="password" required autocomplete="current-password" class="field">
            </div>

            <label class="flex items-center gap-2.5 text-sm text-muted">
                <input type="checkbox" name="remember" value="1" class="size-4 rounded border-line text-brand-900 focus:ring-accent-500">
                Mantener sesión iniciada
            </label>

            <button type="submit" class="btn btn-primary w-full py-3">Entrar</button>
        </form>
    </div>
</body>
</html>
