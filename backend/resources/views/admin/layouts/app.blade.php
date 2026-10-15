<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>@yield('title') · Jin Carwash</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-surface font-sans text-ink antialiased" x-data="{ menu: false }" @keydown.escape="menu = false">

    @php
        $nav = [
            ['route' => 'admin.dashboard', 'match' => 'admin.dashboard', 'label' => 'Inicio', 'icon' => 'home'],
            ['route' => 'admin.users.index', 'match' => 'admin.users.*', 'label' => 'Usuarios', 'icon' => 'users'],
            ['route' => 'admin.audit.index', 'match' => 'admin.audit.*', 'label' => 'Bitácora', 'icon' => 'log'],
        ];
    @endphp

    {{-- Menú lateral: fijo en pantallas grandes, desplegable en celular --}}
    <aside class="fixed inset-y-0 left-0 z-40 flex w-64 -translate-x-full flex-col bg-brand-900 text-white transition-transform duration-200 lg:translate-x-0"
           :class="menu && 'translate-x-0!'">
        <div class="flex h-16 items-center gap-3 px-5">
            <span class="grid size-9 place-items-center rounded-xl bg-accent-500 text-lg font-extrabold">J</span>
            <div class="leading-tight">
                <p class="text-[15px] font-bold">Jin Carwash</p>
                <p class="text-xs text-white/50">Panel administrativo</p>
            </div>
            <button type="button" class="ml-auto rounded-lg p-1.5 text-white/60 hover:bg-white/10 lg:hidden" @click="menu = false" aria-label="Cerrar menú">
                <x-admin.icon name="close" />
            </button>
        </div>

        <nav class="mt-4 flex-1 space-y-1 px-3">
            @foreach ($nav as $item)
                @php $active = request()->routeIs($item['match']); @endphp
                <a href="{{ route($item['route']) }}"
                   @class([
                       'flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition',
                       'bg-white/10 text-white' => $active,
                       'text-white/65 hover:bg-white/5 hover:text-white' => ! $active,
                   ])
                   @if ($active) aria-current="page" @endif>
                    <x-admin.icon :name="$item['icon']" :class="$active ? 'text-accent-500' : ''" />
                    {{ $item['label'] }}
                </a>
            @endforeach
        </nav>

        <div class="border-t border-white/10 p-3">
            <div class="flex items-center gap-3 rounded-xl px-3 py-2">
                <span class="grid size-8 place-items-center rounded-full bg-white/10 text-sm font-semibold">
                    {{ mb_strtoupper(mb_substr(auth()->user()->name, 0, 1)) }}
                </span>
                <div class="min-w-0 flex-1 leading-tight">
                    <p class="truncate text-sm font-semibold">{{ auth()->user()->name }}</p>
                    <p class="truncate text-xs text-white/50">{{ auth()->user()->email }}</p>
                </div>
            </div>
            <form method="POST" action="{{ route('admin.logout') }}">
                @csrf
                <button type="submit" class="mt-1 flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-white/65 transition hover:bg-white/5 hover:text-white">
                    <x-admin.icon name="logout" />
                    Cerrar sesión
                </button>
            </form>
        </div>
    </aside>

    <div x-show="menu" x-cloak x-transition.opacity class="fixed inset-0 z-30 bg-brand-950/50 lg:hidden" @click="menu = false"></div>

    <div class="lg:pl-64">
        <header class="sticky top-0 z-20 flex h-16 items-center gap-3 border-b border-line bg-white/90 px-4 backdrop-blur sm:px-6 lg:px-8">
            <button type="button" class="-ml-1 rounded-lg p-1.5 text-muted hover:bg-surface-2 lg:hidden" @click="menu = true" aria-label="Abrir menú">
                <x-admin.icon name="menu" class="size-6" />
            </button>
            <h1 class="truncate text-lg font-bold tracking-tight">@yield('title')</h1>
            <div class="ml-auto flex items-center gap-2">@yield('actions')</div>
        </header>

        <main class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
            @if (session('status'))
                <div class="mb-5 rounded-xl border border-ok-fg/15 bg-ok-bg px-4 py-3 text-sm font-medium text-ok-fg" role="status">
                    {{ session('status') }}
                </div>
            @endif

            @if ($errors->has('user'))
                <div class="mb-5 rounded-xl border border-bad-fg/15 bg-bad-bg px-4 py-3 text-sm font-medium text-bad-fg" role="alert">
                    {{ $errors->first('user') }}
                </div>
            @endif

            @yield('content')
        </main>
    </div>
</body>
</html>
