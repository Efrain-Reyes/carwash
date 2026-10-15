@extends('admin.layouts.app')

@use('App\Support\Format')

@section('title', 'Usuarios')

@section('actions')
    <a href="{{ route('admin.users.create') }}" class="btn btn-primary">
        <x-admin.icon name="plus" class="size-4" />
        <span class="hidden sm:inline">Nuevo usuario</span>
        <span class="sm:hidden">Nuevo</span>
    </a>
@endsection

@section('content')
    <p class="mb-5 max-w-2xl text-sm text-muted">
        Los administradores entran a la app y a este panel. Los operadores solo usan la app para registrar lavados.
        Al desactivar a alguien se cierran sus sesiones abiertas en la app.
    </p>

    <div class="card overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead class="text-left text-xs font-semibold tracking-wide text-muted uppercase">
                    <tr class="border-b border-line bg-surface/60">
                        <th class="px-5 py-3">Usuario</th>
                        <th class="px-5 py-3">Rol</th>
                        <th class="px-5 py-3">Estado</th>
                        <th class="px-5 py-3">Último acceso</th>
                        <th class="px-5 py-3"><span class="sr-only">Acciones</span></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-line">
                    @foreach ($users as $user)
                        @php
                            $role = $user->roles->first()?->name;
                            $isMe = $user->is(auth()->user());
                        @endphp
                        <tr @class(['opacity-60' => ! $user->is_active])>
                            <td class="px-5 py-3.5">
                                <p class="font-semibold">
                                    {{ $user->name }}
                                    @if ($isMe) <span class="text-xs font-medium text-muted">(tú)</span> @endif
                                </p>
                                <p class="text-xs text-muted">{{ $user->email }}</p>
                            </td>
                            <td class="px-5 py-3.5">
                                <span @class([
                                    'badge',
                                    'bg-info-bg text-info-fg' => $role === 'administrador',
                                    'bg-surface-2 text-ink' => $role !== 'administrador',
                                ])>{{ $roles[$role] ?? 'Sin rol' }}</span>
                            </td>
                            <td class="px-5 py-3.5">
                                @if ($user->is_active)
                                    <span class="badge bg-ok-bg text-ok-fg"><span class="size-1.5 rounded-full bg-ok-fg"></span>Activo</span>
                                @else
                                    <span class="badge bg-bad-bg text-bad-fg"><span class="size-1.5 rounded-full bg-bad-fg"></span>Inactivo</span>
                                @endif
                            </td>
                            <td class="px-5 py-3.5 whitespace-nowrap text-muted" title="{{ Format::dateTime($user->last_login_at) }}">
                                {{ Format::relative($user->last_login_at) }}
                            </td>
                            <td class="px-5 py-3.5">
                                <div class="flex justify-end gap-2">
                                    <a href="{{ route('admin.users.edit', $user) }}" class="btn btn-secondary px-3 py-2">
                                        <x-admin.icon name="edit" class="size-4" /> Editar
                                    </a>
                                    @unless ($isMe)
                                        <form method="POST" action="{{ route('admin.users.toggle', $user) }}"
                                              onsubmit="return confirm(@js($user->is_active ? "¿Desactivar a {$user->name}? Se cerrarán sus sesiones en la app." : "¿Activar a {$user->name}?"))">
                                            @csrf
                                            @method('PATCH')
                                            <button type="submit" @class(['btn px-3 py-2', 'btn-danger' => $user->is_active, 'btn-secondary' => ! $user->is_active])>
                                                {{ $user->is_active ? 'Desactivar' : 'Activar' }}
                                            </button>
                                        </form>
                                    @endunless
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    </div>
@endsection
